const s = @import("structs.zig");
const std = @import("std");

const a = @import("alloc.zig");
const win = @import("windows.zig");
const c = @import("calc.zig");

pub fn save_conf(_save_file: ?[:0]const u8, conf: *const s.Window_conf) !void {
    if (_save_file) |save_file| {
        const save = try conf_to_save(conf);

        var file = try std.fs.cwd().createFile(save_file, .{ .truncate = true });
        defer file.close();

        try std.json.stringify(save, .{ .whitespace = .indent_2 }, file.writer());
    }
}

pub fn load_conf(comptime Save_type: type, _save_file: ?[:0]const u8) !*Save_type {
    if (_save_file) |save_file| {
        const save_str = std.fs.cwd().readFileAlloc(a.allocator, save_file, 999999) catch |e| {
            switch (e) {
                error.FileNotFound => {
                    return default_conf(Save_type);
                },
                else => return e,
            }
        };
        const parsed_conf = try std.json.parseFromSlice(s.Save_conf, a.allocator, save_str, .{});
        return save_to_conf(Save_type, &parsed_conf.value, null);
    }
    return default_conf(Save_type);
}

fn default_conf(comptime Save_type: type) !*Save_type {
    const default_save_conf = s.Save_conf{};
    return save_to_conf(Save_type, &default_save_conf, null);
}

fn conf_to_save(conf: *const s.Window_conf) !*s.Save_conf {
    const left = if (conf.left) |_left| try conf_to_save(_left) else null;
    const right = if (conf.right) |_right| try conf_to_save(_right) else null;
    const save = try a.allocator.create(s.Save_conf);
    save.* = s.Save_conf{
        .left = left,
        .right = right,
        .percent = conf.percent,
        .split_type = conf.split_type,
        .window_type = conf.window_type,
    };
    return save;
}

pub fn save_to_conf(comptime Save_type: type, save: *const s.Save_conf, parent: ?*Save_type) !*Save_type {
    var conf = try a.allocator.create(Save_type);
    if (parent == null and save.window_type != .ALL) {
        return error.RootWindowMustHaveWindowTypeAll;
    } else if (parent != null and save.window_type == .ALL) {
        return error.ChildWindowMusthNotHaveWindowTypeAll;
    }

    switch (Save_type) {
        s.Window_conf => {
            conf.* = s.Window_conf{
                .left = if (save.left) |_left| try save_to_conf(Save_type, _left, conf) else null,
                .right = if (save.right) |_right| try save_to_conf(Save_type, _right, conf) else null,
                .percent = save.percent,
                .split_type = save.split_type,
                .window_type = save.window_type,
                .parent = parent,
                .win = 0,
                .resize = 0,
            };
        },
        s.Snap_conf => {
            const pos = switch (save.window_type) {
                .ALL => s.Window_pos{ .x = 0, .y = 0, .w = win.get_curr_display_width(), .h = win.get_curr_display_height() },
                // as checked earlier: all non .ALL windows have non null parent
                .TOP => s.Window_pos{ .x = parent.?.pos.x, .y = parent.?.pos.y, .w = parent.?.pos.w, .h = c.calc_percent(u32, parent.?.pos.h, parent.?.percent) },
                .BOTTOM => s.Window_pos{ .x = parent.?.pos.x, .y = parent.?.pos.y + c.calc_percent(i32, parent.?.pos.h, parent.?.percent), .w = parent.?.pos.w, .h = c.calc_percent(u32, parent.?.pos.h, 1 - parent.?.percent) },
                .LEFT => s.Window_pos{ .x = parent.?.pos.x, .y = parent.?.pos.y, .w = c.calc_percent(u32, parent.?.pos.w, parent.?.percent), .h = parent.?.pos.h },
                .RIGHT => s.Window_pos{ .x = parent.?.pos.x + c.calc_percent(i32, parent.?.pos.w, parent.?.percent), .y = parent.?.pos.y, .w = c.calc_percent(u32, parent.?.pos.w, 1 - parent.?.percent), .h = parent.?.pos.h },
            };
            // We need to set the parent pos + percent before recursing into left & right
            conf.pos = pos;
            conf.percent = save.percent;
            conf.* = s.Snap_conf{
                .left = if (save.left) |_left| try save_to_conf(Save_type, _left, conf) else null,
                .right = if (save.right) |_right| try save_to_conf(Save_type, _right, conf) else null,
                .percent = save.percent,
                .split_type = save.split_type,
                .window_type = save.window_type,
                .parent = parent,
                .pos = pos,
                .highlighted = false,
            };
        },
        else => @compileError("Can't parse type from save"),
    }
    return conf;
}
