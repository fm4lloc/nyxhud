#!/usr/bin/env python3

# =========================================================
# NyxHud
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2026 Fernando Magalhães
# fm4lloc@gmail.com
# nyx-eco@proton.me
#
# Technical collaboration: Nyx
# =========================================================

MAX_RENDER_SIZE = 32768

MAX_LINES = 256

MAX_LINE_LENGTH = 256

import gi
import cairo
import os
import sys

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

        self.set_name("nyxhud")
        self.set_title("nyxhud")

        # =================================================
        # WINDOW BEHAVIOR
        # =================================================

        self.set_type_hint(
            Gdk.WindowTypeHint.NORMAL
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
        # REALIZE
        # =================================================

        self.connect(
            "realize",
            self.on_realize
        )

        # =================================================
        # REFRESH LOOP
        # =================================================

        GLib.timeout_add(
            1000,
            self.update_hud
        )

        self.update_hud()

    # =====================================================
    # WINDOW REALIZE
    # =====================================================

    def on_realize(self, widget):

        self.move(40, 40)

        empty_region = cairo.Region()

        self.input_shape_combine_region(
            empty_region
        )

    # =====================================================
    # LOAD SNAPSHOTS
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

        for name in files:

            path = os.path.join(
                NYXHUD_RENDER_DIR,
                name
            )

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

                    data = "\n".join(
                        line[:MAX_LINE_LENGTH]
                        for line in data.splitlines()[:MAX_LINES]
                    ).strip()

                    if data:
                        blocks.append(data)

            except Exception:
                pass

        return "\n\n".join(blocks)

    # =====================================================
    # COLORIZE
    # =====================================================

    def colorize(self, text):

        lines = []

        for line in text.splitlines():

            if (
                line.isupper()
                and " " not in line
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
    # HUD UPDATE
    # =====================================================

    def update_hud(self):

        text = self.build_text()

        # =================================================
        # MARKUP ESCAPE
        # =================================================

        safe_text = (
            text
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
        )

        # =================================================
        # SECTION COLORS
        # =================================================

        colored_text = self.colorize(
            safe_text
        )

        # =================================================
        # FINAL RENDER
        # =================================================

        self.label.set_markup(
            (
                "<span "
                "font_desc='Iosevka Term 12' "
                "foreground='#E0E0E0' "
                "weight='bold'>"
                f"{colored_text}"
                "</span>"
            )
        )

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
# START GTK
# =========================================================

try:

    win = NyxHud()

    win.connect(
        "destroy",
        Gtk.main_quit
    )

    win.show_all()

    Gtk.main()

finally:

    try:
        os.rmdir(LOCKDIR)

    except Exception:
        pass