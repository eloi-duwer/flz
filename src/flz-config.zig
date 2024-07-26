const std = @import("std");
const X11 = @import("x11_import.zig");
const g = @import("globals.zig");

const win = @import("windows.zig");
const s = @import("structs.zig");
const save = @import("save.zig");

const a = @import("alloc.zig");
const calc_percent = @import("calc.zig").calc_percent;

pub fn main() !void {
    var args = std.process.args();
    _ = args.skip();
    try g.get_defaults();
    const save_file = args.next();
    const conf = try save.load_conf(s.Window_conf, save_file);
    g.register_xinput_2();
    g.init_fonts();
    win.create_config_win_global();
    try loop(conf);
    try save.save_conf(save_file, conf);
}

fn loop(conf: *s.Window_conf) !void {
    conf.win = try create_win(g.win, conf, .NONE, 0, 1);
    if (!try redraw_windows(conf)) {
        return error.CantDrowConfHere;
    }

    var ev: X11.XEvent = undefined;
    var configuring: ?*s.Window_conf = null;

    while (true) {
        _ = X11.XNextEvent(g.dis, &ev);
        switch (ev.type) {
            X11.KeyPress => {
                if (X11.XkbKeycodeToKeysym(g.dis, @truncate(ev.xkey.keycode), 0, if (ev.xkey.state & X11.ShiftMask != 0) 1 else 0) == X11.XK_Escape) {
                    win.close_overlay();
                    std.debug.print("{}\n", .{conf});
                    return;
                }
            },
            X11.ButtonPress => {
                configuring = try handle_click(conf, ev.xbutton.window, ev.xbutton.button);
            },
            X11.ButtonRelease => {
                if (configuring != null and ev.xbutton.button == X11.Button1) {
                    configuring = null;
                }
            },
            X11.GenericEvent => {
                const cookie: *X11.XGenericEventCookie = &ev.xcookie;
                if (X11.XGetEventData(g.dis, cookie) != 0 and cookie.extension == g.xi_opcode) {
                    if (cookie.evtype == X11.XI_RawMotion) {
                        if (configuring) |conf_resize| {
                            const window_pos = win.get_window_position_relative_to_root(conf_resize.win);
                            const cursor_pos = win.get_cursor_pos(g.win);

                            const cursor_relative_pos = s.Pos{
                                .x = cursor_pos.x - window_pos.x,
                                .y = cursor_pos.y - window_pos.y,
                            };
                            const percents = .{
                                std.math.clamp(@as(f64, @floatFromInt(cursor_relative_pos.x)) / @as(f64, @floatFromInt(window_pos.w)), 0.01, 0.99),
                                std.math.clamp(@as(f64, @floatFromInt(cursor_relative_pos.y)) / @as(f64, @floatFromInt(window_pos.h)), 0.01, 0.99),
                            };
                            const old_percent = conf_resize.percent;
                            conf_resize.percent = if (conf_resize.split_type == .VERTICAL) percents[0] else percents[1];
                            if (!update_windows(conf)) {
                                conf_resize.percent = old_percent;
                                _ = update_windows(conf);
                            }
                        }
                    }
                }
            },
            else => {
                // noop
            },
        }
    }
}

fn handle_click(conf_root: ?*s.Window_conf, target_win: X11.Window, button: c_uint) !?*s.Window_conf {
    var keyboard_state: X11.XkbStateRec = undefined;
    _ = X11.XkbGetState(g.dis, X11.XkbUseCoreKbd, &keyboard_state);

    const is_ctrl_pressed = keyboard_state.mods & X11.ControlMask != 0;
    const is_shift_pressed = keyboard_state.mods & X11.ShiftMask != 0;

    const _conf = find_backing_conf(conf_root, target_win);
    if (_conf) |conf| {
        const is_resize_clicked = conf.resize == target_win;
        if (is_resize_clicked) {
            if (button == X11.Button1) {
                return conf;
            }
        } else if (is_shift_pressed or button == X11.Button2) {
            remove_window(conf);
        } else if (button == X11.Button1 or button == X11.Button3) {
            try split_window(conf, is_ctrl_pressed or button == X11.Button3);
        }
    } else if (conf_root) |conf| {
        _ = conf;
        std.debug.print("Window clicked {} is not in the repertoried list\n", .{target_win});
        return null;
    }
    return null;
}

fn find_backing_conf(_conf: ?*s.Window_conf, window: X11.Window) ?*s.Window_conf {
    if (_conf) |conf| {
        if (conf.win == g.NO_WINDOW) {
            return null;
        }
        if (conf.win == window) {
            return conf;
        }
        if (conf.resize == window) {
            return conf;
        }
        const ret = find_backing_conf(conf.left, window);
        if (ret != null) {
            return ret;
        }
        return find_backing_conf(conf.right, window);
    }
    return null;
}

fn remove_window(_conf: ?*s.Window_conf) void {
    if (_conf) |conf| {
        if (conf.parent) |parent| {
            const pos = win.get_window_dimensions(parent.win);
            clean_subwindows(parent, true);
            // /!\ conf has been freed by clean_subwindows, it's an freed reference at this point
            draw_margins(parent, parent.win, pos.w, pos.h);
        }
    }
}

fn clean_subwindows(conf: *s.Window_conf, is_root: bool) void {
    if (conf.left) |left| {
        clean_subwindows(left, false);
        a.allocator.destroy(left);
        conf.left = null;
    }
    if (conf.right) |right| {
        clean_subwindows(right, false);
        a.allocator.destroy(right);
        conf.right = null;
    }
    if (conf.resize != g.NO_WINDOW) {
        _ = X11.XDestroyWindow(g.dis, conf.resize);
        conf.resize = g.NO_WINDOW;
    }
    if (conf.win != g.NO_WINDOW and !is_root) {
        _ = X11.XDestroyWindow(g.dis, conf.win);
        conf.win = g.NO_WINDOW;
    }
}

fn split_window(_conf: ?*s.Window_conf, is_ctrl_pressed: bool) !void {
    if (_conf) |conf| {
        conf.split_type = if (is_ctrl_pressed) .HORIZONTAL else .VERTICAL;
        conf.percent = 0.5;
        conf.left = try a.allocator.create(s.Window_conf);
        conf.right = try a.allocator.create(s.Window_conf);
        conf.left.?.* = std.mem.zeroes(s.Window_conf);
        conf.right.?.* = std.mem.zeroes(s.Window_conf);
        conf.left.?.parent = conf;
        conf.right.?.parent = conf;
        conf.left.?.window_type = if (conf.split_type == .VERTICAL) .LEFT else .TOP;
        conf.right.?.window_type = if (conf.split_type == .VERTICAL) .RIGHT else .BOTTOM;
        if (!try redraw_windows(conf)) {
            clean_subwindows(conf, true);
        }
    }
}

fn redraw_windows(conf: *s.Window_conf) !bool {
    if (conf.left) |left| {
        left.win = try create_win(conf.win, left, conf.split_type, 0, conf.percent);
        if (left.win == g.NO_WINDOW) {
            return false;
        }
        _ = try redraw_windows(left);
    }
    if (conf.right) |right| {
        right.win = try create_win(conf.win, right, conf.split_type, conf.percent, 1);
        if (right.win == g.NO_WINDOW) {
            return false;
        }
        _ = try redraw_windows(right);
    }
    if ((conf.right != null) and (conf.left != null)) {
        conf.resize = create_resize(conf.win, conf.split_type, conf.percent);
    }
    return true;
}

var prng = std.rand.DefaultPrng.init(0);
var rand = prng.random();

fn create_win(parent: X11.Window, conf: *s.Window_conf, split: s.Split_type, start_percent: f64, end_percent: f64) !X11.Window {
    var xwa = std.mem.zeroes(X11.XSetWindowAttributes);
    xwa.background_pixel = 0xFFFFFFFF;
    xwa.event_mask = X11.KeyPressMask | X11.ButtonPressMask | X11.ButtonReleaseMask;

    const pos = calc_window_needed_dimensions(parent, split, start_percent, end_percent);

    if (pos.w < g.min_size or pos.h < g.min_size) {
        return g.NO_WINDOW;
    }

    const window = X11.XCreateWindow(g.dis, parent, pos.x, pos.y, pos.w, pos.h, 0, X11.DefaultDepth(g.dis, g.screen), X11.InputOutput, g.vis, X11.CWEventMask | X11.CWBackPixel, &xwa);

    _ = X11.XMapWindow(g.dis, window);
    _ = X11.XFlush(g.dis);
    draw_margins(conf, window, pos.w, pos.h);
    try draw_window_size(window, pos);
    return window;
}

fn draw_window_size(window: X11.Window, pos: s.Window_pos) !void {
    const colormap = X11.DefaultColormap(g.dis, 0);
    const draw = X11.XftDrawCreate(g.dis, window, g.vis, colormap);
    const color = win.calc_render_color(0x0, 0x0, 0xFF, 0xFF);
    var xft_color: X11.XftColor = undefined;
    _ = X11.XftColorAllocValue(g.dis, g.vis, colormap, &color, &xft_color);

    const str = try std.fmt.allocPrint(a.allocator, "{} x {}", .{ pos.w, pos.h });
    defer a.allocator.free(str);

    _ = X11.XftDrawString8(draw, &xft_color, g.font, g.margin, g.margin + g.font.height, @ptrCast(str), @intCast(str.len));

    _ = X11.XFlush(g.dis);
    X11.XftDrawDestroy(draw);
    X11.XftColorFree(g.dis, g.vis, colormap, &xft_color);
}

fn update_windows(conf: *s.Window_conf) bool {
    if (conf.left) |left| {
        if (!update_win(conf.win, left, conf.split_type, 0, conf.percent) or !update_windows(left)) {
            return false;
        }
    }
    if (conf.right) |right| {
        if (!update_win(conf.win, right, conf.split_type, conf.percent, 1) or !update_windows(right)) {
            return false;
        }
    }
    if (conf.resize != g.NO_WINDOW) {
        const resize_pos = get_resize_pos(conf.win, conf.split_type, conf.percent);
        _ = X11.XMoveResizeWindow(g.dis, conf.resize, resize_pos.x, resize_pos.y, resize_pos.w, resize_pos.h);
    }
    return true;
}

fn update_win(parent: X11.Window, conf: *s.Window_conf, split: s.Split_type, start_percent: f64, end_percent: f64) bool {
    if (conf.win == g.NO_WINDOW) {
        return true;
    }
    const pos = calc_window_needed_dimensions(parent, split, start_percent, end_percent);

    if (pos.w < g.min_size or pos.h < g.min_size) {
        return false;
    }

    _ = X11.XMoveResizeWindow(g.dis, conf.win, pos.x, pos.y, pos.w, pos.h);
    draw_margins(conf, conf.win, pos.w, pos.h);
    draw_window_size(conf.win, pos) catch unreachable;
    return true;
}

fn calc_window_needed_dimensions(parent: X11.Window, split: s.Split_type, start_percent: f64, end_percent: f64) s.Window_pos {
    const parent_pos = win.get_window_dimensions(parent);

    if (split == .VERTICAL) {
        return s.Window_pos{
            .x = calc_percent(i32, parent_pos.w, start_percent),
            .y = 0,
            .w = calc_percent(u32, parent_pos.w, end_percent - start_percent),
            .h = parent_pos.h,
        };
    } else {
        return s.Window_pos{
            .x = 0,
            .y = calc_percent(i32, parent_pos.h, start_percent),
            .w = parent_pos.w,
            .h = calc_percent(u32, parent_pos.h, end_percent - start_percent),
        };
    }
}

fn draw_margins(conf: *s.Window_conf, window: X11.Window, w: u32, h: u32) void {
    const pos_margin = s.Window_pos{ .x = 0 + g.margin / 2, .y = 0 + g.margin / 2, .w = w - g.margin / 2, .h = h - g.margin / 2 };
    if (is_on_top(conf)) {
        _ = X11.XDrawLine(g.dis, window, g.gc, 0, @intCast(pos_margin.y), @intCast(w), @intCast(pos_margin.y));
    } else {
        _ = X11.XDrawLine(g.dis, window, g.gc, 0, 0, @intCast(w), 0);
    }
    if (is_on_right(conf)) {
        _ = X11.XDrawLine(g.dis, window, g.gc, @intCast(pos_margin.w), 0, @intCast(pos_margin.w), @intCast(h));
    } else {
        _ = X11.XDrawLine(g.dis, window, g.gc, @intCast(w), 0, @intCast(w), @intCast(h));
    }
    if (is_on_bottom(conf)) {
        _ = X11.XDrawLine(g.dis, window, g.gc, @intCast(w), @intCast(pos_margin.h), 0, @intCast(pos_margin.h));
    } else {
        _ = X11.XDrawLine(g.dis, window, g.gc, @intCast(w), @intCast(h), 0, @intCast(h));
    }
    if (is_on_left(conf)) {
        _ = X11.XDrawLine(g.dis, window, g.gc, @intCast(pos_margin.x), @intCast(h), @intCast(pos_margin.x), 0);
    } else {
        _ = X11.XDrawLine(g.dis, window, g.gc, 0, @intCast(h), 0, 0);
    }
}

fn is_on_top(conf: *s.Window_conf) bool {
    if (conf.window_type == .BOTTOM) {
        return false;
    }
    if (conf.parent) |parent| {
        return is_on_top(parent);
    } else {
        return true;
    }
}

fn is_on_bottom(conf: *s.Window_conf) bool {
    if (conf.window_type == .TOP) {
        return false;
    }
    if (conf.parent) |parent| {
        return is_on_bottom(parent);
    } else {
        return true;
    }
}

fn is_on_left(conf: *s.Window_conf) bool {
    if (conf.window_type == .RIGHT) {
        return false;
    }
    if (conf.parent) |parent| {
        return is_on_left(parent);
    } else {
        return true;
    }
}

fn is_on_right(conf: *s.Window_conf) bool {
    if (conf.window_type == .LEFT) {
        return false;
    }
    if (conf.parent) |parent| {
        return is_on_right(parent);
    } else {
        return true;
    }
}

fn get_resize_pos(window: X11.Window, split_type: s.Split_type, percent: f64) s.Window_pos {
    const window_pos = win.get_window_dimensions(window);

    return if (split_type == .HORIZONTAL) s.Window_pos{
        .x = @intFromFloat(calc_percent(f64, window_pos.w, 0.5) - g.resize_half),
        .y = @intFromFloat(calc_percent(f64, window_pos.h, percent) - g.resize_half),
        .h = g.resize_size,
        .w = g.resize_size,
    } else s.Window_pos{
        .x = @intFromFloat(calc_percent(f64, window_pos.w, percent) - g.resize_half),
        .y = @intFromFloat(calc_percent(f64, window_pos.h, 0.5) - g.resize_half),
        .h = g.resize_size,
        .w = g.resize_size,
    };
}

fn create_resize(parent: X11.Window, split_type: s.Split_type, percent: f64) X11.Window {
    var xwa = std.mem.zeroes(X11.XSetWindowAttributes);
    xwa.background_pixel = X11.BlackPixel(g.dis, g.screen);
    xwa.event_mask = X11.KeyPressMask | X11.ButtonPressMask | X11.ButtonReleaseMask;

    const pos = get_resize_pos(parent, split_type, percent);

    const window = X11.XCreateWindow(
        g.dis,
        parent,
        pos.x,
        pos.y,
        pos.w,
        pos.h,
        0,
        X11.DefaultDepth(g.dis, g.screen),
        X11.InputOutput,
        g.vis,
        X11.CWEventMask | X11.CWBackPixel,
        &xwa,
    );

    const cursor = X11.XCreateFontCursor(g.dis, if (split_type == .VERTICAL) X11.XC_sb_h_double_arrow else X11.XC_sb_v_double_arrow);
    _ = X11.XDefineCursor(g.dis, window, cursor);
    _ = X11.XMapWindow(g.dis, window);
    _ = X11.XFlush(g.dis);
    return window;
}
