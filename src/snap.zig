const X11 = @import("x11_import.zig").X11;
const g = @import("globals.zig");
const std = @import("std");

const Pos = struct {
    x: i64,
    y: i64,
};

pub fn snap_window(win: X11.Window, n_configuring: *u8) void {
    var pos: Pos = undefined;
    var xy: Pos = undefined;
    var wh: Pos = undefined;
    get_cursor_pos(&pos);
    get_workable_area(&xy, &wh);
    const slice_size: i64 = @divTrunc(wh.x, g.zone_count);
    const win_group: i64 = @divTrunc(pos.x, slice_size);

    snap_to_with_parents(n_configuring, win, win_group * slice_size, 0, slice_size, wh.y);
}

fn get_cursor_pos(ret_pos: *Pos) void {
    var _root: X11.Window = undefined;
    var _win: X11.Window = undefined;
    var _x: c_int = undefined;
    var _y: c_int = undefined;
    var _mask: c_uint = undefined;
    var x: c_int = undefined;
    var y: c_int = undefined;

    _ = X11.XQueryPointer(g.dis, g.root, &_root, &_win, &x, &y, &_x, &_y, &_mask);
    ret_pos.x = x;
    ret_pos.y = y;
}

fn get_workable_area(xy: *Pos, wh: *Pos) void {
    var n_items: c_ulong = undefined;
    var coords_ret: [*c]u8 = undefined;

    get_property_value(g.root, "_NET_WORKAREA", 32 * 4, &n_items, &coords_ret);
    const coords: [*]c_ulong = @alignCast(@ptrCast(coords_ret));
    xy.x = @intCast(coords[0]);
    xy.y = @intCast(coords[1]);
    wh.x = @intCast(@as(i64, @intCast(coords[2])) - xy.x);
    wh.y = @intCast(@as(i64, @intCast(coords[3])) - xy.y);
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

const Margins = struct { left: i64, top: i64, right: i64, bottom: i64 };

fn snap_to_with_parents(n_configuring: *u8, win: X11.Window, x: i64, y: i64, width: i64, height: i64) void {
    (n_configuring.*) += 1;
    var margins: Margins = undefined;
    get_window_margin(win, &margins);
    std.debug.print("Snapping {} to {} {} {} {}\n", .{ win, x, y, width, height });
    _ = X11.XMoveResizeWindow(g.dis, win, @intCast(x - margins.right), @intCast(y - margins.top), @intCast(width + margins.right + margins.left), @intCast(height + margins.top + margins.bottom));
    var parent: X11.Window = undefined;
    if (get_parent_window(win, &parent) == true and n_configuring.* < 100) {
        snap_to_with_parents(n_configuring, parent, x, y, width, height);
    }
}

fn get_window_margin(win: X11.Window, margins: *Margins) void {
    var n_items: c_ulong = undefined;
    var prop: [*c]u8 = undefined;
    get_property_value(win, "_GTK_FRAME_EXTENTS", 4, &n_items, &prop);
    if (n_items == 0) {
        margins.left = 0;
        margins.right = 0;
        margins.top = 0;
        margins.bottom = 0;
    } else {
        const nums: [*]c_ulong = @alignCast(@ptrCast(prop));
        margins.left = @intCast(nums[0]);
        margins.right = @intCast(nums[1]);
        margins.top = @intCast(nums[2]);
        margins.bottom = @intCast(nums[3]);
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
