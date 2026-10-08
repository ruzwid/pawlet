"""Finder layout for Pawlet's floating-island installer (800 × 540 points)."""

# dmgbuild supplies `defines` when loading this settings file.
application = defines["app"]  # noqa: F821
files = [application, (defines["readme"], "Read Me.txt")]  # noqa: F821
symlinks = {"Applications": "/Applications"}
icon = defines["icon"]  # noqa: F821
background = defines["background"]  # noqa: F821
format = "UDZO"
filesystem = "HFS+"

# Finder's bounds include window chrome. Leave room for users who keep its
# status/path bars visible, so the complete 540-point artwork still fits.
window_rect = ((160, 120), (800, 604))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
include_icon_view_settings = True
include_list_view_settings = False
arrange_by = None
scroll_position = (0, 0)
icon_size = 88
text_size = 15
label_pos = "bottom"
# Finder already hides .app. SetFile on the signed bundle would add FinderInfo
# metadata and invalidate strict signature verification after packaging.
hide_extensions = ["Read Me.txt"]
icon_locations = {
    "Pawlet.app": (230, 270),
    "Applications": (570, 270),
    "Read Me.txt": (700, 435),
    # Keep the install canvas clear even when Finder's Show Hidden Files is on.
    ".background.tiff": (1200, 700),
    ".VolumeIcon.icns": (1350, 700),
}
