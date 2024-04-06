const X11 = @import("x11_import.zig");

pub var dis: *X11.Display = undefined;
pub var screen: c_int = undefined;
pub var root: X11.Window = undefined;
pub var xi_opcode: c_int = undefined;
pub var win: X11.Window = undefined;
pub var gc: X11.GC = undefined;
pub var vis: *X11.Visual = undefined;

pub const zone_count = 3;
pub const margin = 20;
pub const alpha = 0.3;
pub const min_size = 100;

pub fn get_defaults() !void {
    dis = X11.XOpenDisplay(null) orelse return error.InitializationError;
    screen = X11.XDefaultScreen(dis);
    root = X11.XDefaultRootWindow(dis);
    vis = X11.XDefaultVisual(dis, screen);

    var queryEvent: c_int = undefined;
    var queryError: c_int = undefined;
    const ret = X11.XQueryExtension(dis, "XInputExtension", &xi_opcode, &queryEvent, &queryError);
    if (ret == X11.False) {
        return error.InitializationError;
    }
}

const XIEventMask = extern struct {
    deviceid: c_int,
    mask_len: c_int,
    mask: anyopaque,
};

fn set_mask(mask: []u8, event: u8) void {
    var slice = mask[event >> 3];
    slice |= (@as(u8, 1) <<| (event & 7));
    mask[event >> 3] = slice;
}

pub fn register_xinput_2() void {
    const mask_len: comptime_int = X11.XIMaskLen(X11.XI_LASTEVENT);
    var mask: [mask_len]u8 = .{0} ** mask_len;
    var m = X11.XIEventMask{
        .deviceid = X11.XIAllMasterDevices,
        .mask_len = X11.XIMaskLen(X11.XI_LASTEVENT),
        .mask = &mask,
    };
    set_mask(&mask, X11.XI_RawKeyPress);
    set_mask(&mask, X11.XI_RawKeyPress);
    set_mask(&mask, X11.XI_RawKeyRelease);
    set_mask(&mask, X11.XI_RawButtonPress);
    set_mask(&mask, X11.XI_RawButtonRelease);
    set_mask(&mask, X11.XI_RawMotion);
    _ = X11.XISelectEvents(dis, root, &m, 1);
    _ = X11.XSync(dis, 0);
}

pub fn register_window_move() void {
    // Get notified when a window is reconfigured (= moved/resized)
    _ = X11.XSelectInput(dis, root, X11.SubstructureNotifyMask);
}
