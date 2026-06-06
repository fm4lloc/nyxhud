#!/usr/bin/env python3

# =========================================================
# NyxHud
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2026 Fernando Magalhães
# fm4lloc@gmail.com
# nyx-eco@proton.me
#
# =========================================================

MAX_RENDER_SIZE = 32768

MAX_LINES = 256

MAX_LINE_LENGTH = 256

REFRESH_INTERVAL_MS = 1000

RENDER_TTL = 15

WINDOW_MARGIN = 40

import os
import sys
import html
import atexit

import gi
import cairo
import time

gi.require_version('Gtk', '3.0')

from gi.repository import Gtk
from gi.repository import GLib
from gi.repository import Gdk

# =========================================================
# PATHS
# =========================================================

XDG_RUNTIME_DIR = os.environ.get(
    "XDG_RUNTIME_DIR",
    "/tmp"
)

NYXHUD_RUNTIME_DIR = os.path.join(
    XDG_RUNTIME_DIR,
    "nyxhud"
)

NYXHUD_RENDER_DIR = os.path.join(
    NYXHUD_RUNTIME_DIR,
    "render"
)

LOCKDIR = os.path.join(
    NYXHUD_RUNTIME_DIR,
    "renderer.lock"
)

# =========================================================
# GTK WINDOW
# =========================================================

class NyxHud(Gtk.Window):

    def __init__(self):

        Gtk.Window.__init__(
            self,
            type=Gtk.WindowType.TOPLEVEL
        )

        # =================================================
        # RENDER STATE
        # =================================================

        self.file_cache = {}

        self.file_mtimes = {}

        self.last_markup = ""

        # =================================================
        # WINDOW IDENTITY
        # =================================================

        self.set_name("nyxhud")

        self.set_title("nyxhud")

        self.set_role("nyxhud")

        # =================================================
        # WINDOW BEHAVIOR
        # =================================================

        self.set_type_hint(
            Gdk.WindowTypeHint.DESKTOP
        )

        self.set_decorated(False)

        self.set_skip_taskbar_hint(True)

        self.set_skip_pager_hint(True)

        self.set_keep_below(True)

        self.set_accept_focus(False)

        self.stick()

        self.set_resizable(False)

        # =================================================
        # RGBA VISUAL
        # =================================================

        screen = self.get_screen()

        visual = screen.get_rgba_visual()

        if visual:

            self.set_visual(visual)

        self.set_app_paintable(True)

        # =================================================
        # GTK CSS
        # =================================================

        css = b"""
        window,
        window.background,
        window.tooltip,
        decoration,
        decoration:backdrop {

            background-color: transparent;
            box-shadow: none;
            border: none;
            margin: 0;
            padding: 0;
        }
        """

        provider = Gtk.CssProvider()

        provider.load_from_data(css)

        Gtk.StyleContext.add_provider_for_screen(
            screen,
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        # =================================================
        # LABEL
        # =================================================

        self.label = Gtk.Label()

        self.label.set_justify(
            Gtk.Justification.LEFT
        )

        self.label.set_halign(
            Gtk.Align.START
        )

        self.label.set_valign(
            Gtk.Align.START
        )

        self.label.set_selectable(False)

        self.label.set_use_markup(True)

        self.label.set_line_wrap(False)

        # =================================================
        # MARGINS
        # =================================================

        self.label.set_margin_top(30)

        self.label.set_margin_bottom(30)

        self.label.set_margin_start(30)

        self.label.set_margin_end(30)

        self.add(self.label)

        # =================================================
        # EVENTS
        # =================================================

        self.connect(
            "realize",
            self.on_realize
        )

        self.connect(
            "draw",
            self.on_draw
        )

        # =================================================
        # INITIAL UPDATE
        # =================================================

        self.update_hud()

        # =================================================
        # REFRESH LOOP
        # =================================================

        GLib.timeout_add(
            REFRESH_INTERVAL_MS,
            self.update_hud
        )

    # =====================================================
    # WINDOW POSITION
    # =====================================================

    def position_window(self):

        display = self.get_display()

        monitor = display.get_monitor(0)

        geometry = monitor.get_geometry()

        width, height = self.get_size()

        x = WINDOW_MARGIN

        y = (
            geometry.height
            - height
            - WINDOW_MARGIN
        )

        self.move(x, y)

        return False

    # =====================================================
    # POST REALIZE
    # =====================================================

    def post_realize(self):

        gdk_window = self.get_window()

        if gdk_window is None:

            return True

        # =================================================
        # FORCE STACKING
        # =================================================

        gdk_window.lower()

        self.set_keep_below(True)

        # =================================================
        # POSITION
        # =================================================

        self.position_window()

        return False

    # =====================================================
    # WINDOW REALIZE
    # =====================================================

    def on_realize(self, widget):

        empty_region = cairo.Region()

        self.input_shape_combine_region(
            empty_region
        )

        GLib.idle_add(
            self.post_realize
        )

    # =====================================================
    # TRANSPARENT DRAW
    # =====================================================

    def on_draw(self, widget, cr):

        cr.set_source_rgba(
            0.0,
            0.0,
            0.0,
            0.0
        )

        cr.set_operator(
            cairo.OPERATOR_SOURCE
        )

        cr.paint()

        return False

    # =====================================================
    # LOAD RENDER FILE
    # =====================================================

    def load_render_file(self, path):

        try:

            with open(
                path,
                "r",
                encoding="utf-8",
                errors="replace"
            ) as f:

                data = f.read(
                    MAX_RENDER_SIZE
                )

        except Exception:

            return ""

        lines = []

        for line in data.splitlines()[:MAX_LINES]:

            lines.append(
                line[:MAX_LINE_LENGTH]
            )

        return "\n".join(lines).strip()

    # =====================================================
    # EXPIRED SNAPSHOT
    # =====================================================

    def is_expired(self, mtime):

        now = int(time.time())

        return (
            (now - int(mtime))
            > RENDER_TTL
        )

    # =====================================================
    # BUILD TEXT
    # =====================================================

    def build_text(self):

        blocks = []

        try:

            files = sorted(
                f for f in os.listdir(
                    NYXHUD_RENDER_DIR
                )
                if f.endswith(".render")
            )

        except Exception:

            return ""

        valid_paths = set()

        for name in files:

            path = os.path.join(
                NYXHUD_RENDER_DIR,
                name
            )

            valid_paths.add(path)

            try:

                stat = os.stat(path)

            except Exception:

                continue

            mtime = int(stat.st_mtime)

            # =============================================
            # STALE SNAPSHOT
            # =============================================

            if self.is_expired(mtime):

                self.file_cache.pop(
                    path,
                    None
                )

                self.file_mtimes.pop(
                    path,
                    None
                )

                continue

            # =============================================
            # CACHE HIT
            # =============================================

            old_mtime = self.file_mtimes.get(path)

            if old_mtime == mtime:

                cached = self.file_cache.get(
                    path
                )

                if cached:

                    blocks.append(cached)

                continue

            # =============================================
            # RELOAD
            # =============================================

            text = self.load_render_file(
                path
            )

            self.file_mtimes[path] = mtime

            self.file_cache[path] = text

            if text:

                blocks.append(text)

        # =================================================
        # PURGE DELETED FILES
        # =================================================

        stale = []

        for path in self.file_cache:

            if path not in valid_paths:

                stale.append(path)

        for path in stale:

            self.file_cache.pop(
                path,
                None
            )

            self.file_mtimes.pop(
                path,
                None
            )

        return "\n\n".join(blocks)

    # =====================================================
    # COLORIZE
    # =====================================================

    def colorize(self, text):

        lines = []

        for line in text.splitlines():

            stripped = line.strip()

            # =============================================
            # SECTION HEADER
            # =============================================

            if (
                stripped
                and len(stripped) <= 32
                and stripped.upper() == stripped
                and any(c.isalpha() for c in stripped)
                and not any(c.isdigit() for c in stripped)
                and ":" not in stripped
            ):

                lines.append(
                    (
                        "<span "
                        "foreground='#1793d1' "
                        "weight='bold'>"
                        f"{line}"
                        "</span>"
                    )
                )

            else:

                lines.append(line)

        return "\n".join(lines)

    # =====================================================
    # BUILD MARKUP
    # =====================================================

    def build_markup(self, text):

        safe_text = html.escape(text)

        colored_text = self.colorize(
            safe_text
        )

        return (
            "<span "
            "font_desc='Iosevka Term 12' "
            "foreground='#E0E0E0' "
            "weight='bold'>"
            f"{colored_text}"
            "</span>"
        )

    # =====================================================
    # HUD UPDATE
    # =====================================================

    def update_hud(self):

        text = self.build_text()

        markup = self.build_markup(
            text
        )

        # =================================================
        # NO CHANGES
        # =================================================

        if markup == self.last_markup:

            return True

        # =================================================
        # UPDATE LABEL
        # =================================================

        self.label.set_markup(markup)

        self.last_markup = markup

        return True

# =========================================================
# SINGLETON LOCK
# =========================================================

try:

    os.mkdir(LOCKDIR)

except FileExistsError:

    print(
        "[nyxhud] renderer already running",
        file=sys.stderr
    )

    sys.exit(1)

# =========================================================
# CLEANUP
# =========================================================

def cleanup():

    try:

        os.rmdir(LOCKDIR)

    except OSError:

        pass


atexit.register(cleanup)

# =========================================================
# START GTK
# =========================================================

win = NyxHud()

win.connect(
    "destroy",
    Gtk.main_quit
)

win.show_all()

Gtk.main()