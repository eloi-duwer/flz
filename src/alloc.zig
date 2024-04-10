const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub var allocator = gpa.allocator();
