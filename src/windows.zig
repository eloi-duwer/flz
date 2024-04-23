const X11 = @import("x11_import.zig");

const g = @import("globals.zig");

const std = @import("std");

const s = @import("structs.zig");

pub fn create_config_win_global() void {
    var xwa = std.mem.zeroes(X11.XSetWindowAttributes);
    xwa.background_pixel = X11.WhitePixel(g.dis, g.screen);
    xwa.event_mask = X11.KeyPressMask | X11.ButtonPressMask | X11.PointerMotionMask | X11.ButtonReleaseMask;
    var vinfo: X11.XVisualInfo = undefined;
    _ = X11.XMatchVisualInfo(g.dis, g.screen, 32, X11.TrueColor, &vinfo);
    g.win = X11.XCreateWindow(g.dis, X11.DefaultRootWindow(g.dis), 0, 0, 42, 42, 42, X11.DefaultDepth(g.dis, g.screen), X11.InputOutput, g.vis, X11.CWEventMask | X11.CWBackPixel, &xwa);

    create_gc_margins();

    set_transparent(g.alpha_config, g.win);
    remove_window_interface();

    _ = X11.XClearWindow(g.dis, g.win);
    _ = X11.XMapWindow(g.dis, g.win);
    set_above();

    _ = X11.XMoveResizeWindow(g.dis, g.win, 0, 0, get_curr_display_width(), get_curr_display_height());

    _ = X11.XFlush(g.dis);
    std.time.sleep(30_000_000);
    _ = X11.XSetInputFocus(g.dis, g.win, X11.RevertToParent, X11.CurrentTime);
}

pub fn create_gc_margins() void {
    g.gc = X11.XCreateGC(g.dis, g.win, 0, 0);

    _ = X11.XSetLineAttributes(g.dis, g.gc, g.margin, X11.LineSolid, X11.CapRound, X11.JoinMiter);
}

pub fn set_transparent(alpha: f64, win: X11.Window) void {
    const opacity: c_ulong = @intFromFloat(@as(f64, @floatFromInt(0xFFFFFFFF)) * alpha);
    const atom_opacity = X11.XInternAtom(g.dis, "_NET_WM_WINDOW_OPACITY", X11.False);
    _ = X11.XChangeProperty(g.dis, win, atom_opacity, X11.XA_CARDINAL, 32, X11.PropModeReplace, @ptrCast(&opacity), 1);
}

fn remove_window_interface() void {
    const atom_type = X11.XInternAtom(g.dis, "_NET_WM_WINDOW_TYPE", X11.False);
    const atom_value = X11.XInternAtom(g.dis, "_NET_WM_WINDOW_TYPE_SPLASH", X11.False);
    _ = X11.XChangeProperty(g.dis, g.win, atom_type, X11.XA_ATOM, 32, X11.PropModeReplace, @ptrCast(&atom_value), 1);
}

fn set_above() void {
    const wm_state = X11.XInternAtom(g.dis, "_NET_WM_STATE", X11.False);
    const wm_state_above = X11.XInternAtom(g.dis, "_NET_WM_STATE_ABOVE", X11.False);
    _ = X11.XChangeProperty(g.dis, g.win, wm_state, X11.XA_ATOM, 32, X11.PropModeReplace, @ptrCast(&wm_state_above), 1);
}

pub fn get_curr_display_width() c_uint {
    return @intCast(X11.DisplayWidth(g.dis, g.screen));
}

pub fn get_curr_display_height() c_uint {
    return @intCast(X11.DisplayHeight(g.dis, g.screen));
}

pub fn close_overlay() void {
    _ = X11.XFreeGC(g.dis, g.gc);
    _ = X11.XDestroyWindow(g.dis, g.win);
    g.win = g.NO_WINDOW;
}

pub fn open_overlay(conf: s.Snap_conf) *X11.Display {
    var xwa = std.mem.zeroes(X11.XSetWindowAttributes);
    xwa.background_pixel = X11.WhitePixel(g.dis, g.screen);
    xwa.event_mask = 0;
    var vinfo: X11.XVisualInfo = undefined;
    _ = X11.XMatchVisualInfo(g.dis, g.screen, 32, X11.TrueColor, &vinfo);
    g.win = X11.XCreateWindow(g.dis, X11.DefaultRootWindow(g.dis), 0, 0, 42, 42, 0, X11.DefaultDepth(g.dis, g.screen), X11.InputOutput, g.vis, X11.CWEventMask | X11.CWBackPixel, &xwa);

    create_gc_margins();

    set_transparent(g.alpha_config, g.win);
    remove_window_interface();

    set_dont_intercept_inputs();

    _ = X11.XClearWindow(g.dis, g.win);
    _ = X11.XMapWindow(g.dis, g.win);
    set_above();

    _ = X11.XMoveResizeWindow(g.dis, g.win, 0, 0, get_curr_display_width(), get_curr_display_height());

    _ = X11.XFlush(g.dis);

    const color = get_color(g.margin_color);
    _ = X11.XSetForeground(g.dis, g.gc, color);
    _ = X11.XFlush(g.dis);

    draw_overlay_margins(conf, g.win);
    _ = X11.XFlush(g.dis);

    _ = X11.XSetForeground(g.dis, g.gc, get_color(g.snap_color));
    return g.dis;
}

fn draw_overlay_margins(conf: s.Snap_conf, win: X11.Window) void {
    if (conf.left) |left| {
        draw_overlay_margins(left.*, win);
    }
    if (conf.right) |right| {
        draw_overlay_margins(right.*, win);
    }
    if (conf.left == null and conf.right == null) {
        const x: c_int = conf.pos.x;
        const y: c_int = conf.pos.y;
        const xw: c_int = conf.pos.x + @as(c_int, @intCast(conf.pos.w));
        const yh: c_int = conf.pos.y + @as(c_int, @intCast(conf.pos.h));
        _ = X11.XDrawLine(g.dis, win, g.gc, x, y, xw, y);
        _ = X11.XDrawLine(g.dis, win, g.gc, xw, y, xw, yh);
        _ = X11.XDrawLine(g.dis, win, g.gc, xw, yh, x, yh);
        _ = X11.XDrawLine(g.dis, win, g.gc, x, yh, x, y);
        std.time.sleep(10_000_000); // why is this needed :(
    }
}

pub fn get_color(color_string: [*]const u8) c_ulong {
    var color: X11.XColor = undefined;

    const colormap = X11.DefaultColormap(g.dis, 0);
    _ = X11.XParseColor(g.dis, colormap, color_string, &color);
    return color.pixel;
}

fn set_dont_intercept_inputs() void {
    var rect: X11.XRectangle = undefined;
    const region = X11.XFixesCreateRegion(g.dis, &rect, 1);
    X11.XFixesSetWindowShapeRegion(g.dis, g.win, X11.ShapeInput, 0, 0, region);
    X11.XFixesDestroyRegion(g.dis, region);
}

pub fn get_active_window() X11.Window {
    var focused: X11.Window = undefined;
    var revert: c_int = undefined;

    _ = X11.XGetInputFocus(g.dis, &focused, &revert);
    return focused;
}

pub fn get_window_dimensions(window: X11.Window) s.Window_pos {
    var attrs: X11.XWindowAttributes = undefined;
    _ = X11.XGetWindowAttributes(g.dis, window, &attrs);

    return s.Window_pos{
        .x = @intCast(attrs.x),
        .y = @intCast(attrs.y),
        .w = @intCast(attrs.width),
        .h = @intCast(attrs.height),
    };
}

pub fn get_window_position_relative_to_root(window: X11.Window) s.Window_pos {
    const curr_pos = get_window_dimensions(window);
    var x: c_int = undefined;
    var y: c_int = undefined;
    var child: X11.Window = undefined;
    _ = X11.XTranslateCoordinates(g.dis, window, g.win, 0, 0, &x, &y, &child);
    return s.Window_pos{
        .x = @intCast(x),
        .y = @intCast(y),
        .w = curr_pos.w,
        .h = curr_pos.h,
    };
}

pub fn get_cursor_pos(win_relative_to: X11.Window) s.Pos {
    var _root: X11.Window = undefined;
    var _win: X11.Window = undefined;
    var _x: c_int = undefined;
    var _y: c_int = undefined;
    var _mask: c_uint = undefined;
    var x: c_int = undefined;
    var y: c_int = undefined;

    _ = X11.XQueryPointer(g.dis, win_relative_to, &_root, &_win, &x, &y, &_x, &_y, &_mask);
    return s.Pos{
        .x = x,
        .y = y,
    };
}
