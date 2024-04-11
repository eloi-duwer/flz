const s = @import("structs.zig");
const std = @import("std");

const a = @import("alloc.zig");

pub fn save_conf(_save_file: ?[:0]const u8, conf: *const s.Window_conf) !void {
    if (_save_file) |save_file| {
        const save = try conf_to_save(conf);

        var file = try std.fs.cwd().createFile(save_file, .{ .truncate = true });
        defer file.close();

        try std.json.stringify(save, .{ .whitespace = .indent_2 }, file.writer());
    }
}

pub fn load_conf(_save_file: ?[:0]const u8) !*s.Window_conf {
    if (_save_file) |save_file| {
        const save_str = std.fs.cwd().readFileAlloc(a.allocator, save_file, 999999) catch |e| {
            switch (e) {
                error.FileNotFound => {
                    return default_conf();
                },
                else => return e,
            }
        };
        const parsed_conf = try std.json.parseFromSlice(s.Save_conf, a.allocator, save_str, .{});
        return save_to_conf(&parsed_conf.value, null);
    }
    return default_conf();
}

fn default_conf() !*s.Window_conf {
    const default_save_conf = s.Save_conf{};
    return save_to_conf(&default_save_conf, null);
}

fn conf_to_save(conf: *const s.Window_conf) !*s.Save_conf {
    const left = if (conf.left) |_left| try conf_to_save(_left) else null;
    const right = if (conf.right) |_right| try conf_to_save(_right) else null;
    var save = try a.allocator.create(s.Save_conf);
    save.* = s.Save_conf{
        .left = left,
        .right = right,
        .percent = conf.percent,
        .split_type = conf.split_type,
        .window_type = conf.window_type,
    };
    return save;
}

pub fn save_to_conf(save: *const s.Save_conf, parent: ?*s.Window_conf) !*s.Window_conf {
    var conf = try a.allocator.create(s.Window_conf);

    conf.* = s.Window_conf{
        .left = if (save.left) |_left| try save_to_conf(_left, conf) else null,
        .right = if (save.right) |_right| try save_to_conf(_right, conf) else null,
        .percent = save.percent,
        .split_type = save.split_type,
        .window_type = save.window_type,
        .parent = parent,
        .win = 0,
        .resize = 0,
    };
    return conf;
}
