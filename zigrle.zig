const std = @import("std");
const testing = std.testing;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const input = "WWWWWBBBBWWWW";
    std.debug.print("Input: {s}\n", .{input});

    const compressed = try compress(allocator, input);
    defer allocator.free(compressed);

    std.debug.print("Compressed: ", .{});
    var i: usize = 0;
    while (i < compressed.len) : (i += 2) {
        std.debug.print("{d}{c}", .{ compressed[i], compressed[i + 1] });
    }
    std.debug.print("\n", .{});
}

fn compress(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    if (input.len == 0) return allocator.dupe(u8, "");
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    var count: u8 = 0;
    var current: u8 = 0;

    var temp_allocator = std.heap.ArenaAllocator.init(allocator);
    defer temp_allocator.deinit();
    const temp = temp_allocator.allocator();

    for (input) |char| {
        if (count == 0 or char != current) {
            if (count > 0) {
                const count_str = try std.fmt.allocPrint(temp, "{d}", .{count});
                try result.appendSlice(count_str);
                try result.append(current);
            }
            current = char;
            count = 1;
        } else {
            count += 1;
        }
        if (count == 255) {
            const count_str = try std.fmt.allocPrint(temp, "{d}", .{count});
            try result.appendSlice(count_str);
            try result.append(current);
            count = 0;
        }
    }

    if (count > 0) {
        const count_str = try std.fmt.allocPrint(temp, "{d}", .{count});
        try result.appendSlice(count_str);
        try result.append(current);
    }

    return result.toOwnedSlice();
}

test "RLE compression - basic case" {
    const allocator = testing.allocator;
    const input = "WWWWWBBBBWWWW";
    const compressed = try compress(allocator, input);
    defer allocator.free(compressed);
    try testing.expectEqualSlices(u8, "5W4B4W", compressed);
}

test "RLE compression - single character" {
    const allocator = testing.allocator;
    const input = "AAAAA";
    const compressed = try compress(allocator, input);
    defer allocator.free(compressed);
    try testing.expectEqualSlices(u8, "5A", compressed);
}

test "RLE compression - no repetition" {
    const allocator = testing.allocator;
    const input = "ABCDE";
    const compressed = try compress(allocator, input);
    defer allocator.free(compressed);
    try testing.expectEqualSlices(u8, "1A1B1C1D1E", compressed);
}

test "RLE compression - empty input" {
    const allocator = testing.allocator;
    const input = "";
    const compressed = try compress(allocator, input);
    defer allocator.free(compressed);
    try testing.expectEqualSlices(u8, "", compressed);
}

test "RLE compression - long run" {
    const allocator = testing.allocator;
    var input: [256]u8 = undefined;
    @memset(&input, 'A');
    const compressed = try compress(allocator, &input);
    defer allocator.free(compressed);
    try testing.expectEqualSlices(u8, "255A1A", compressed);
}
