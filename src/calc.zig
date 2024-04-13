const std = @import("std");

pub fn calc_percent(comptime Ret_type: type, n: anytype, percent: f64) Ret_type {
    _ = .{ n, percent };
    const info = @typeInfo(Ret_type);
    const res = @as(f64, @floatFromInt(n)) * percent;
    if (info == .Float) {
        return @as(Ret_type, res);
    } else {
        return @as(Ret_type, @intFromFloat(res));
    }
}
