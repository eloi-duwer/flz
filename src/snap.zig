const X11 = @import("x11_import.zig");
const g = @import("globals.zig");
const std = @import("std");
const s = @import("structs.zig");
const window = @import("windows.zig");

pub fn snap_window(win: X11.Window, _conf: s.Snap_conf, n_configuring: *u8) void {
    const pos = window.get_cursor_pos(g.root);

    if (find_backing_leaf_conf(&_conf, pos)) |conf| {
        snap_to_with_parents(n_configuring, win, conf.pos.x, conf.pos.y, conf.pos.w, conf.pos.h);
    }
}

pub fn find_leaf_confs_near_cursor(conf: *const s.Snap_conf, cursor_pos: s.Pos) [5]?*const s.Snap_conf {
    var ret: [5]?*const s.Snap_conf = .{null} ** 5;
    var n_found: u8 = 0;

    // Can't loop over -1..1 ;(
    for (0..3) |_i| {
        inner: for (0..3) |_j| {
            const i: i64 = @as(i64, @intCast(_i)) - 1;
            const j: i64 = @as(i64, @intCast(_j)) - 1;
            if ((j == 0 and i != 0) or (i == 0 and j != 0)) {
                continue :inner;
            }
            const new_pos = s.Pos{ .x = cursor_pos.x + g.snap_near_pos_margin * i, .y = cursor_pos.y + g.snap_near_pos_margin * j };
            if (find_backing_leaf_conf(conf, new_pos)) |backing_conf| {
                ret[n_found] = backing_conf;
                n_found += 1;
            }
        }
    }
    return ret;
}

pub fn find_backing_leaf_conf(conf: *const s.Snap_conf, cursor_pos: s.Pos) ?*const s.Snap_conf {
    if (conf.left == null and conf.right == null) {
        const p = conf.pos;
        if (p.x <= cursor_pos.x and @as(u32, @intCast(p.x)) + p.w >= cursor_pos.x and p.y <= cursor_pos.y and @as(u32, @intCast(p.y)) + p.h >= cursor_pos.y) {
            return conf;
        }
        return null;
    }

    if (conf.left) |left| {
        const l = find_backing_leaf_conf(left, cursor_pos);
        if (l != null) {
            return l;
        }
    }
    if (conf.right) |right| {
        const r = find_backing_leaf_conf(right, cursor_pos);
        if (r != null) {
            return r;
        }
    }
    return null;
}

fn get_workable_area() s.Window_pos {
    var n_items: c_ulong = undefined;
    var coords_ret: [*c]u8 = undefined;

    get_property_value(g.root, "_NET_WORKAREA", 32 * 4, &n_items, &coords_ret);
    const coords: [*]c_ulong = @alignCast(@ptrCast(coords_ret));
    const x: i32 = @intCast(coords[0]);
    const y: i32 = @intCast(coords[1]);

    return s.Window_pos{
        .x = x,
        .y = y,
        .w = @intCast(@as(i64, @intCast(coords[2])) - x),
        .h = @intCast(@as(i64, @intCast(coords[3])) - y),
    };
}

fn get_property_value(win: X11.Window, propname: [*]const u8, max_length: c_long, n_items_return: *c_ulong, prop_return: [*c][*c]u8) void {
    var result: c_int = undefined;
    var property: X11.Atom = undefined;
    var actual_type_return: X11.Atom = undefined;
    var actual_format_return: c_int = undefined;
    var bytes_after_return: c_ulong = undefined;

    property = X11.XInternAtom(g.dis, propname, X11.True);

    result = X11.XGetWindowProperty(g.dis, win, property, 0, // offset
        max_length, // length
        X11.False, // delete
        X11.AnyPropertyType, // req_type
        &actual_type_return, &actual_format_return, n_items_return, &bytes_after_return, prop_return);
}

fn snap_to_with_parents(n_configuring: *u8, win: X11.Window, x: i64, y: i64, width: i64, height: i64) void {
    (n_configuring.*) += 1;
    const margins = get_window_margin(win);
    _ = X11.XMoveResizeWindow(g.dis, win, @intCast(x - margins.right), @intCast(y - margins.top), @intCast(width + margins.right + margins.left), @intCast(height + margins.top + margins.bottom));
    var parent: X11.Window = undefined;
    if (get_parent_window(win, &parent) == true and n_configuring.* < 100) {
        snap_to_with_parents(n_configuring, parent, x, y, width, height);
    }
}

fn get_window_margin(win: X11.Window) s.Margins {
    var n_items: c_ulong = undefined;
    var prop: [*c]u8 = undefined;
    get_property_value(win, "_GTK_FRAME_EXTENTS", 4, &n_items, &prop);
    if (n_items == 0) {
        return s.Margins{
            .left = 0,
            .right = 0,
            .top = 0,
            .bottom = 0,
        };
    } else {
        const nums: [*]c_ulong = @alignCast(@ptrCast(prop));
        return s.Margins{
            .left = @intCast(nums[0]),
            .right = @intCast(nums[1]),
            .top = @intCast(nums[2]),
            .bottom = @intCast(nums[3]),
        };
    }
}

fn get_parent_window(win: X11.Window, ret_win: *X11.Window) bool {
    var root: X11.Window = undefined;
    var parent: X11.Window = undefined;
    var childs: [*c]X11.Window = undefined;
    var n_childs: c_uint = undefined;
    _ = X11.XQueryTree(g.dis, win, &root, &parent, &childs, &n_childs);
    if (childs != null) {
        _ = X11.XFree(childs);
    }
    if (parent != root) {
        ret_win.* = parent;
        return true;
    }
    return false;
}
