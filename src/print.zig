const s = @import("structs.zig");
const std = @import("std");

const spaces = blk: {
    var _spaces: [100]u8 = undefined;
    for (&_spaces, 0.._spaces.len) |*sp, i| {
        _ = i;
        sp.* = ' ';
    }
    break :blk _spaces;
};

pub fn print_conf(conf: *s.Window_conf, depth: usize) void {
    _ = .{ depth, conf };
    const n_spaces = depth * 2;
    if (n_spaces > spaces.len) {
        return;
    }
    std.debug.print("{s}|-> {s} Window {} {} {d:.2} {}\n", .{ spaces[0..n_spaces], print_type(conf.window_type), conf.win, conf.split_type, conf.percent, conf.resize });
    if (conf.left) |left| {
        print_conf(left, depth + 1);
    }
    if (conf.right) |right| {
        print_conf(right, depth + 1);
    }
}

fn print_type(win_type: s.Window_type) *const [6:0]u8 {
    return switch (win_type) {
        .ALL => "Root  ",
        .TOP => "Top   ",
        .BOTTOM => "Bottom",
        .LEFT => "Left  ",
        .RIGHT => "Right ",
    };
}
