const X11 = @import("x11_import.zig").X11;

pub var dis: ?*X11.Display = undefined;
pub var screen: c_int = undefined;
pub var root: X11.Window = undefined;
pub var xi_opcode: c_int = undefined;
pub var win: X11.Window = undefined;
pub var gc: X11.GC = undefined;
pub var vis: *X11.Visual = undefined;

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
