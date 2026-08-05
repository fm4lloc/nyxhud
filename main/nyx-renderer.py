#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Fernando Magalhães <fm4lloc@gmail.com>

import os
import sys
import html
import re
import stat
import time
import signal

try:
    import gi

    gi.require_version("Gtk", "3.0")
    gi.require_version("GtkLayerShell", "0.1")
    gi.require_version("PangoCairo", "1.0")

    from gi.repository import Gtk, GLib, Gio, GtkLayerShell, Pango, PangoCairo
    import cairo
except (ImportError, ValueError) as exc:
    sys.stderr.write(f"nyx-renderer: missing dependency: {exc}\n")
    sys.exit(1)

try:
    gi.require_version("GLibUnix", "2.0")
    from gi.repository import GLibUnix
except (ImportError, ValueError):
    GLibUnix = None

if GLibUnix is not None and hasattr(GLibUnix, "signal_add"):
    unix_signal_add = GLibUnix.signal_add
else:
    unix_signal_add = GLib.unix_signal_add

MAX_BLOCK_BYTES = 32768
MAX_LINES = 128
MAX_COLUMNS = 96
DEBOUNCE_MS = 120
RECONCILE_S = 5

CONTROL_CHARS = dict.fromkeys(
    [c for c in range(0x20) if c not in (0x09, 0x0A)]
    + [0x7F]
    + list(range(0x80, 0xA0))
)

ANCHORS = {
    "top-left": (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.LEFT),
    "top-right": (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.RIGHT),
    "bottom-left": (GtkLayerShell.Edge.BOTTOM, GtkLayerShell.Edge.LEFT),
    "bottom-right": (GtkLayerShell.Edge.BOTTOM, GtkLayerShell.Edge.RIGHT),
}


COLOR_RE = re.compile(r"\A#(?:[0-9A-Fa-f]{3,4}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})\Z")
COLOR_NAMES = frozenset(
    ("black", "white", "red", "green", "blue", "cyan", "magenta", "yellow",
     "gray", "grey", "orange", "purple", "brown", "pink")
)


def env_color(name, default):
    value = os.environ.get(name, default)
    if COLOR_RE.match(value) or value.lower() in COLOR_NAMES:
        return value
    sys.stderr.write(f"nyx-renderer: {name}={value!r} is not a colour, using {default}\n")
    return default


def env_int(name, default, low, high):
    try:
        value = int(os.environ[name])
    except (KeyError, ValueError):
        return default
    return value if low <= value <= high else default


TTL = env_int("NYXHUD_TTL", 15, 2, 3600)
MARGIN = env_int("NYXHUD_MARGIN", 40, 0, 4096)
PADDING = env_int("NYXHUD_PADDING", 24, 0, 512)
FONT = os.environ.get("NYXHUD_FONT", "Iosevka Term 12")
TEXT_COLOR = env_color("NYXHUD_TEXT_COLOR", "#E0E0E0")
TITLE_COLOR = env_color("NYXHUD_TITLE_COLOR", "#1793D1")
ANCHOR = os.environ.get("NYXHUD_ANCHOR", "bottom-left")
if ANCHOR not in ANCHORS:
    sys.stderr.write(
        f"nyx-renderer: NYXHUD_ANCHOR={ANCHOR!r} is not a corner, using bottom-left\n"
    )
    ANCHOR = "bottom-left"
OUTPUT = os.environ.get("NYXHUD_OUTPUT", "")


def resolve_runtime_dir():
    override = os.environ.get("NYXHUD_RUNTIME_DIR", "")
    if override:
        if not os.path.isabs(override):
            sys.stderr.write(
                "nyx-renderer: NYXHUD_RUNTIME_DIR must be an absolute path\n"
            )
            sys.exit(1)
        return override
    base = os.environ.get("XDG_RUNTIME_DIR", "")
    if not base:
        sys.stderr.write(
            "nyx-renderer: XDG_RUNTIME_DIR is unset; "
            "set NYXHUD_RUNTIME_DIR to a private directory\n"
        )
        sys.exit(1)
    return os.path.join(base, "nyxhud")


RUNTIME_DIR = resolve_runtime_dir()
RENDER_DIR = os.environ.get("NYXHUD_RENDER_DIR") or os.path.join(RUNTIME_DIR, "render")
LOCK_DIR = os.path.join(RUNTIME_DIR, "renderer.lock")


def sanitize(text):
    return text.translate(CONTROL_CHARS)


def read_block(path):
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
    except OSError:
        return None
    try:
        with os.fdopen(fd, "r", encoding="utf-8", errors="replace") as handle:
            info = os.fstat(handle.fileno())
            if not stat.S_ISREG(info.st_mode):
                return None
            if time.time() - info.st_mtime > TTL:
                return None
            raw = handle.read(MAX_BLOCK_BYTES)
    except OSError:
        return None

    lines = [sanitize(line)[:MAX_COLUMNS] for line in raw.splitlines()[:MAX_LINES]]
    while lines and not lines[-1].strip():
        lines.pop()
    return lines or None


def build_markup(blocks):
    parts = []
    for lines in blocks:
        title = html.escape(lines[0])
        body = html.escape("\n".join(lines[1:]))
        chunk = f"<span foreground='{TITLE_COLOR}'>{title}</span>"
        if body:
            chunk += "\n" + body
        parts.append(chunk)
    inner = "\n\n".join(parts)
    return f"<span foreground='{TEXT_COLOR}' weight='bold'>{inner}</span>"


def markup_is_valid(markup):
    try:
        Pango.parse_markup(markup, -1, "\0")
        return True
    except GLib.Error:
        return False
    except Exception as exc:  # noqa: BLE001
        sys.stderr.write(f"nyx-renderer: markup check unavailable: {exc}\n")
        return False


class HudArea(Gtk.DrawingArea):
    def __init__(self):
        super().__init__()

        self._width = 1
        self._height = 1
        self._text = None
        self._inode = None
        self._monitor = None
        self._debounce = None

        surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, 1, 1)
        self._cr = cairo.Context(surface)
        self._layout = PangoCairo.create_layout(self._cr)
        self._layout.set_font_description(Pango.FontDescription(FONT))

        self._arm_monitor()
        GLib.timeout_add_seconds(RECONCILE_S, self._reconcile)
        self.refresh()

    def _arm_monitor(self):
        if self._monitor is not None:
            self._monitor.cancel()
            self._monitor = None
        try:
            gfile = Gio.File.new_for_path(RENDER_DIR)
            self._monitor = gfile.monitor_directory(Gio.FileMonitorFlags.NONE, None)
            self._monitor.connect("changed", self._on_change)
            self._inode = os.stat(RENDER_DIR).st_ino
        except (GLib.Error, OSError):
            self._monitor = None
            self._inode = None

    def _reconcile(self):
        try:
            inode = os.stat(RENDER_DIR).st_ino
        except OSError:
            inode = None
        if self._monitor is None or inode != self._inode:
            self._arm_monitor()
        self.refresh()
        return True

    def _on_change(self, *_args):
        if self._debounce is not None:
            GLib.source_remove(self._debounce)
        self._debounce = GLib.timeout_add(DEBOUNCE_MS, self._on_debounce)

    def _on_debounce(self):
        self._debounce = None
        self.refresh()
        return False

    def refresh(self):
        try:
            names = sorted(
                name
                for name in os.listdir(RENDER_DIR)
                if name.endswith(".render") and not name.startswith(".")
            )
        except OSError:
            names = []

        blocks = []
        for name in names:
            lines = read_block(os.path.join(RENDER_DIR, name))
            if lines:
                blocks.append(lines)

        markup = build_markup(blocks)
        if markup == self._text:
            return
        self._text = markup

        if not markup_is_valid(markup):
            plain = "\n\n".join("\n".join(lines) for lines in blocks)
            self._layout.set_text(plain, -1)
        else:
            self._layout.set_markup(markup, -1)

        PangoCairo.update_layout(self._cr, self._layout)
        width, height = self._layout.get_pixel_size()
        self._width = width + 2 * PADDING
        self._height = height + 2 * PADDING

        self.queue_resize()
        self.queue_draw()

    def do_get_preferred_width(self):
        return self._width, self._width

    def do_get_preferred_height(self):
        return self._height, self._height

    def do_draw(self, cr):
        cr.set_operator(cairo.OPERATOR_SOURCE)
        cr.set_source_rgba(0, 0, 0, 0)
        cr.paint()
        cr.set_operator(cairo.OPERATOR_OVER)
        cr.translate(PADDING, PADDING)
        PangoCairo.update_layout(cr, self._layout)
        PangoCairo.show_layout(cr, self._layout)
        return False


def pick_monitor(window):
    if not OUTPUT:
        return None
    display = window.get_display()
    for index in range(display.get_n_monitors()):
        monitor = display.get_monitor(index)
        if monitor is not None and monitor.get_model() == OUTPUT:
            return monitor
    sys.stderr.write(f"nyx-renderer: output {OUTPUT} not found, using default\n")
    return None


def build_window():
    if not GtkLayerShell.is_supported():
        sys.stderr.write("nyx-renderer: requires a wlr-layer-shell compositor\n")
        sys.exit(1)

    window = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
    window.set_decorated(False)
    window.set_resizable(False)
    window.set_app_paintable(True)

    visual = window.get_screen().get_rgba_visual()
    if visual is not None:
        window.set_visual(visual)

    GtkLayerShell.init_for_window(window)
    if hasattr(GtkLayerShell, "set_namespace"):
        GtkLayerShell.set_namespace(window, "nyxhud")

    monitor = pick_monitor(window)
    if monitor is not None and hasattr(GtkLayerShell, "set_monitor"):
        GtkLayerShell.set_monitor(window, monitor)

    GtkLayerShell.set_layer(window, GtkLayerShell.Layer.BOTTOM)
    GtkLayerShell.set_keyboard_mode(window, GtkLayerShell.KeyboardMode.NONE)
    GtkLayerShell.set_exclusive_zone(window, -1)

    for edge in ANCHORS.get(ANCHOR, ANCHORS["bottom-left"]):
        GtkLayerShell.set_anchor(window, edge, True)
        GtkLayerShell.set_margin(window, edge, MARGIN)

    return window


def acquire_lock():
    pid_file = os.path.join(LOCK_DIR, "pid")
    try:
        os.makedirs(RENDER_DIR, mode=0o700, exist_ok=True)
        os.mkdir(LOCK_DIR, 0o700)
    except FileExistsError:
        owner = None
        try:
            with open(pid_file, encoding="utf-8") as handle:
                owner = int(handle.read().strip())
        except (OSError, ValueError):
            owner = None
        if owner is not None:
            try:
                os.kill(owner, 0)
                sys.stderr.write(f"nyx-renderer: already running (pid {owner})\n")
                sys.exit(1)
            except OSError:
                pass
        sys.stderr.write("nyx-renderer: taking over stale lock\n")
        try:
            os.unlink(pid_file)
        except OSError:
            pass
        try:
            os.rmdir(LOCK_DIR)
        except OSError:
            pass
        try:
            os.mkdir(LOCK_DIR, 0o700)
        except OSError:
            sys.stderr.write("nyx-renderer: lost the race for the stale lock\n")
            sys.exit(1)
    except OSError as exc:
        sys.stderr.write(f"nyx-renderer: cannot prepare runtime dir: {exc}\n")
        sys.exit(1)

    with open(pid_file, "w", encoding="utf-8") as handle:
        handle.write(f"{os.getpid()}\n")
    return pid_file


def release_lock(pid_file):
    try:
        os.unlink(pid_file)
        os.rmdir(LOCK_DIR)
    except OSError:
        pass


def main():
    if not Gtk.init_check()[0]:
        sys.stderr.write("nyx-renderer: cannot open display\n")
        sys.exit(1)

    pid_file = acquire_lock()

    window = build_window()
    window.add(HudArea())
    window.connect("destroy", Gtk.main_quit)
    window.show_all()

    def quit_now():
        Gtk.main_quit()
        return GLib.SOURCE_REMOVE

    for sig in (signal.SIGINT, signal.SIGTERM):
        unix_signal_add(GLib.PRIORITY_DEFAULT, sig, quit_now)

    try:
        Gtk.main()
    finally:
        release_lock(pid_file)


if __name__ == "__main__":
    main()
