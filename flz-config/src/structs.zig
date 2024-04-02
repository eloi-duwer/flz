const X11 = @import("x11_import.zig").X11;

pub const Window_type = enum { ALL, TOP, BOTTOM, LEFT, RIGHT };

pub const Split_type = enum { NONE, VERTICAL, HORIZONTAL };

pub const Window_conf = struct {
    win: X11.Window,
    window_type: Window_type,
    resize: X11.Window,
    split_type: Split_type,
    percent: f64,
    parent: ?*Window_conf,
    left: ?*Window_conf,
    right: ?*Window_conf,
};

pub const Window_pos = struct {
    x: i32,
    y: i32,
    w: u32,
    h: u32,
};
