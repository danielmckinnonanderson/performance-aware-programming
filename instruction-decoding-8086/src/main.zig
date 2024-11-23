const std = @import("std");

pub const Mode = enum {
    assemble,
    disassemble,
};

pub const ConfigParseErr = error{
    missing_required_arg,
    conflicting_mode,
    missing_value,
    unknown_argument,
};

pub const Config = struct {
    mode: Mode,
    input: ?[]const u8 = null,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // If config can't be parsed, print the help message and exit
    const config = parseArgs(args) catch |err| {
        const stderr = std.io.getStdErr().writer();
        try stderr.print("Error: {}\n", .{err});
        try stderr.print("Usage: {s} (-a|-d) [-i <input>]\n", .{args[0]});
        try stderr.print("  -a           Assemble mode\n", .{});
        try stderr.print("  -d           Disassemble mode\n", .{});
        try stderr.print("  -i <input>   Input file (defaults to stdin if omitted)\n", .{});
        return err;
    };

    _ = config;
}

pub fn parseArgs(args: []const []const u8) ConfigParseErr!Config {
    var app_mode: ?Mode = null;
    var input: ?[]const u8 = null;
    var i: usize = 1; // Skip program name

    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (arg.len == 0) continue;

        if (!std.mem.startsWith(u8, arg, "-")) {
            return ConfigParseErr.unknown_argument;
        }

        if (std.mem.eql(u8, arg, "-a")) {
            if (app_mode != null) return ConfigParseErr.conflicting_mode;
            app_mode = .assemble;
            continue;
        } else if (std.mem.eql(u8, arg, "-d")) {
            if (app_mode != null) return ConfigParseErr.conflicting_mode;
            app_mode = .disassemble;
            continue;
        } else if (std.mem.eql(u8, arg, "-i")) {
            i += 1;
            if (i >= args.len) return ConfigParseErr.missing_value;
            input = args[i];
            continue;
        }

        return ConfigParseErr.unknown_argument;
    }

    if (app_mode == null) return ConfigParseErr.missing_required_arg;

    return Config{
        .mode = app_mode.?,
        .input = input,
    };
}

fn disassemble(f: *std.fs.File) !void {
    _ = f;
}

test "parser rejects missing mode argument" {
    const test_args = [_][]const u8{ "program", "-i", "input.txt" };
    const result = parseArgs(&test_args);
    try std.testing.expectError(ConfigParseErr.missing_required_arg, result);
}

test "parser rejects conflicting modes" {
    const test_args = [_][]const u8{ "program", "-a", "-d" };
    const result = parseArgs(&test_args);
    try std.testing.expectError(ConfigParseErr.conflicting_mode, result);
}

test "parser rejects missing input value" {
    const test_args = [_][]const u8{ "program", "-a", "-i" };
    const result = parseArgs(&test_args);
    try std.testing.expectError(ConfigParseErr.missing_value, result);
}

test "parser rejects unknown arguments" {
    const test_args = [_][]const u8{ "program", "-a", "-x" };
    const result = parseArgs(&test_args);
    try std.testing.expectError(ConfigParseErr.unknown_argument, result);
}

test "parser accepts valid assemble config" {
    const test_args = [_][]const u8{ "program", "-a", "-i", "input.txt" };
    const config = try parseArgs(&test_args);
    try std.testing.expectEqual(Mode.assemble, config.mode);
    try std.testing.expectEqualStrings("input.txt", config.input.?);
}

test "parser accepts valid disassemble config" {
    const test_args = [_][]const u8{ "program", "-d", "-i", "input.txt" };
    const config = try parseArgs(&test_args);
    try std.testing.expectEqual(Mode.disassemble, config.mode);
    try std.testing.expectEqualStrings("input.txt", config.input.?);
}

test "parser accepts mode with no input (defaults to null)" {
    const test_args = [_][]const u8{ "program", "-a" };
    const config = try parseArgs(&test_args);
    try std.testing.expectEqual(Mode.assemble, config.mode);
    try std.testing.expect(config.input == null);
}
