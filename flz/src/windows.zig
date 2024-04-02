const std = @import("std");

const s = @import("structs.zig");
const g = @import("globals.zig");

const X11 = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/extensions/XInput2.h");
    @cInclude("X11/Xlib.h");
    @cInclude("X11/Xutil.h");
    @cInclude("X11/Xos.h");
    @cInclude("X11/Xatom.h");
    @cInclude("X11/extensions/shape.h");
    @cInclude("X11/extensions/Xfixes.h");
    @cInclude("X11/extensions/XInput2.h");
});

const base_color: [*]const u8 = "#ffffff";
const base_alpha = 0.2;

pub fn open_overlay() *X11.Display {
    const white = X11.WhitePixel(g.dis, g.screen);
    var v_info: X11.XVisualInfo = undefined;

    _ = X11.XMatchVisualInfo(g.dis, g.screen, 32, X11.TrueColor, &v_info);
    g.win = X11.XCreateSimpleWindow(g.dis, X11.DefaultRootWindow(g.dis), 0, 0, 42, 42, 42, white, get_color(base_color));
    g.gc = X11.XCreateGC(g.dis, g.win, 0, 0);

    set_transparent(base_alpha);
    remove_window_interface();
    set_dont_intercept_inputs();

    _ = X11.XClearWindow(g.dis, g.win);
    _ = X11.XMapWindow(g.dis, g.win);
    set_above();

    _ = X11.XMoveResizeWindow(g.dis, g.win, 0, 0, get_curr_display_width(), get_curr_display_height());
    return g.dis;
}

fn get_color(color_string: [*]const u8) c_ulong {
    var color: X11.XColor = undefined;

    const colormap = X11.DefaultColormap(g.dis, 0);
    _ = X11.XParseColor(g.dis, colormap, color_string, &color);
    return color.pixel;
}

fn set_transparent(alpha: f64) void {
    const opacity: c_ulong = @intFromFloat(@as(f64, 0xFFFFFFFF) * alpha);
    const atom_opacity: X11.Atom = X11.XInternAtom(g.dis, "_NET_WM_WINDOW_OPACITY", 0);
    _ = X11.XChangeProperty(g.dis, g.win, atom_opacity, X11.XA_CARDINAL, 32, X11.PropModeReplace, @ptrCast(&opacity), 1);
}

fn remove_window_interface() void {
    const win_type = X11.XInternAtom(g.dis, "_NET_WM_WINDOW_TYPE", 0);
    const value = X11.XInternAtom(g.dis, "_NET_WM_WINDOW_TYPE_SPLASH", 0);
    _ = X11.XChangeProperty(g.dis, g.win, win_type, X11.XA_ATOM, 32, X11.PropModeReplace, @ptrCast(&value), 1);
}

fn set_dont_intercept_inputs() void {
    var rect: X11.XRectangle = undefined;
    const region = X11.XFixesCreateRegion(g.dis, &rect, 1);
    X11.XFixesSetWindowShapeRegion(g.dis, g.win, X11.ShapeInput, 0, 0, region);
    X11.XFixesDestroyRegion(g.dis, region);
}

fn set_above() void {
    const wm_state = X11.XInternAtom(g.dis, "_NET_WM_STATE", 0);
    const wm_state_above = X11.XInternAtom(g.dis, "_NET_WM_STATE_ABOVE", 0);
    _ = X11.XChangeProperty(g.dis, g.win, wm_state, X11.XA_ATOM, 32, X11.PropModeReplace, @ptrCast(&wm_state_above), 1);
}

fn get_curr_display_width() c_uint {
    return @intCast(X11.DisplayWidth(g.dis, g.screen));
}

fn get_curr_display_height() c_uint {
    return @intCast(X11.DisplayHeight(g.dis, g.screen));
}

pub fn close_overlay() void {
    _ = X11.XFreeGC(g.dis, g.gc);
    _ = X11.XDestroyWindow(g.dis, g.win);
}

pub fn get_active_window() X11.Window {
    var focused: X11.Window = undefined;
    var revert: c_int = undefined;

    _ = X11.XGetInputFocus(g.dis, &focused, &revert);
    return focused;
}
