const std = @import("std");
const X11 = @import("x11_import.zig");
const g = @import("globals.zig");

const win = @import("windows.zig");
const s = @import("structs.zig");
const snap = @import("snap.zig");
const save = @import("save.zig");

pub fn main() !void {
    try g.get_defaults();
    g.register_xinput_2();
    g.register_window_move();

    var args = std.process.args();
    _ = args.skip();
    const save_file = args.next();
    const conf = try save.load_conf(s.Snap_conf, save_file);

    loop(conf.*);
}

fn loop(conf: s.Snap_conf) noreturn {
    var ev: X11.XEvent = undefined;
    const cookie: *X11.XGenericEventCookie = &ev.xcookie;
    var state = s.Open_state{};

    const ctrll = X11.XKeysymToKeycode(g.dis, X11.XK_Control_L);
    const ctrlr = X11.XKeysymToKeycode(g.dis, X11.XK_Control_R);

    while (true) {
        _ = X11.XNextEvent(g.dis, &ev);
        if (X11.XGetEventData(g.dis, cookie) != 0) {
            if (cookie.type == X11.GenericEvent and cookie.extension == g.xi_opcode) {
                if (cookie.evtype == X11.XI_RawKeyPress or cookie.evtype == X11.XI_RawKeyRelease or cookie.evtype == X11.XI_RawButtonPress or cookie.evtype == X11.XI_RawButtonRelease) {
                    const raw_data: *X11.XIRawEvent = @alignCast(@ptrCast(cookie.data));
                    const detail = raw_data.detail;
                    const ctrl_pressed = detail == ctrll or detail == ctrlr;
                    const button_pressed = detail == X11.Button1 or detail == X11.Button3;
                    if (cookie.evtype == X11.XI_RawKeyPress and ctrl_pressed) {
                        // open_snap
                        state.ctrl_down = true;
                        handle_open_snap(conf, &state);
                    }
                    if (cookie.evtype == X11.XI_RawKeyRelease and ctrl_pressed) {
                        handle_ctrl_up(&state);
                    }
                    if (cookie.evtype == X11.XI_RawButtonPress and button_pressed) {
                        // Nothing
                    }
                    if (cookie.evtype == X11.XI_RawButtonRelease and button_pressed) {
                        handle_button_release(&state);
                    }
                }
            }
            if (cookie.evtype == X11.XI_RawMotion and state.opened) {
                handle_mouse_motion(&state, conf);
            }
        }
        if (ev.type == X11.ConfigureNotify) {
            if (state.n_configuring > 0) {
                state.n_configuring -= 1;
            } else {
                state.configuring = true;
                handle_open_snap(conf, &state);
            }
        }
        X11.XFreeEventData(g.dis, cookie);
    }
}

// Open the overlay only if we're not already & if we're configuring while ctrl is down
fn handle_open_snap(conf: s.Snap_conf, state: *s.Open_state) void {
    if (!state.opened and state.configuring and state.ctrl_down) {
        state.opened = true;
        _ = win.open_overlay(conf);
        prev_targetting_zones = std.mem.zeroes(@TypeOf(prev_targetting_zones));
    }
}

fn handle_ctrl_up(state: *s.Open_state) void {
    state.ctrl_down = false;
    if (state.opened) {
        state.opened = false;
        win.close_overlay();
    }
}

fn handle_button_release(state: *s.Open_state) void {
    state.configuring = false;
    if (state.opened) {
        state.opened = false;
        state.n_configuring += 1;
        // There's a conflict between X11 configuring the window & us moving it, waiting a bit before snapping
        std.time.sleep(10_000_000); // 0.01s
        const curr_focus_window = win.get_active_window();
        snap.snap_window(curr_focus_window, &state.n_configuring, prev_targetting_zones);
        win.close_overlay();
    }
}

var prev_targetting_zones: [5]?*const s.Snap_conf = .{null} ** 5;

fn handle_mouse_motion(state: *s.Open_state, conf: s.Snap_conf) void {
    if (state.opened and g.win != g.NO_WINDOW) {
        const cursor_pos = win.get_cursor_pos(g.root);
        const near_confs = snap.find_leaf_confs_near_cursor(&conf, cursor_pos);

        if (has_target_changed(near_confs)) {
            for (prev_targetting_zones) |_zone| {
                if (_zone) |zone| {
                    const p = zone.pos;
                    const color = win.calc_render_color(255, 255, 255, 255);

                    const format = X11.XRenderFindVisualFormat(g.dis, g.vis);
                    const picture = X11.XRenderCreatePicture(g.dis, g.win, format, 0, null);

                    X11.XRenderFillRectangle(g.dis, X11.PictOpSrc, picture, &color, p.x + g.margin / 2, p.y + g.margin / 2, p.w - g.margin, p.h - g.margin);
                }
            }

            copy_targets(near_confs);
            for (near_confs) |_backing_conf| {
                if (_backing_conf) |backing_conf| {
                    const p = backing_conf.pos;

                    var color = win.calc_render_color(0, 0, 0, 255);

                    const format = X11.XRenderFindVisualFormat(g.dis, g.vis);
                    const picture = X11.XRenderCreatePicture(g.dis, g.win, format, 0, null);

                    X11.XRenderFillRectangle(g.dis, X11.PictOpSrc, picture, &color, p.x + g.margin / 2, p.y + g.margin / 2, p.w - g.margin, p.h - g.margin);
                }
            }
        }
    }
}

fn has_target_changed(targetting_zones: [5]?*const s.Snap_conf) bool {
    for (targetting_zones, 0..) |zone, i| {
        if (i == prev_targetting_zones.len) {
            return false;
        }
        if (zone != prev_targetting_zones[i]) {
            return true;
        }
    }
    if (targetting_zones.len < prev_targetting_zones.len and prev_targetting_zones[targetting_zones.len] != null) {
        return true;
    }
    return false;
}

fn copy_targets(targetting_zones: [5]?*const s.Snap_conf) void {
    for (0..prev_targetting_zones.len) |i| {
        if (i < targetting_zones.len) {
            prev_targetting_zones[i] = targetting_zones[i];
        } else {
            prev_targetting_zones[i] = null;
        }
    }
}
