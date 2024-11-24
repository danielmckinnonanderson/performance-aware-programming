const std = @import("std");

pub const ConfigParseErr = error{
    missing_required_arg,
    conflicting_mode,
    missing_value,
    unknown_argument,
};

pub const Config = struct {
    mode: Mode,
    input: ?[]const u8 = null,

    pub const Mode = enum {
        assemble,
        disassemble,
    };

    pub const HELP_MESSAGE =
        \\Usage: {s} (-a|-d) [-i <input>]
        \\ -a           Assemble mode
        \\ -d           Disassemble mode
        \\ -i <input>   Input file (defaults to stdin if omitted)
    ;
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Process args to create program config struct
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const config = parseArgs(args) catch |err| {
        // If config can't be parsed, print the help message and exit
        const stderr = std.io.getStdErr().writer();
        try stderr.print("Error: {}\n", .{err});
        try stderr.print(Config.HELP_MESSAGE, .{args[0]});
        return err;
    };

    const input_file = if (config.input == null)
        // Default to stdin if no input path was passed
        std.io.getStdIn()
    else
        try std.fs.cwd().openFile(config.input.?, .{});
    defer input_file.close();

    switch (config.mode) {
        Config.Mode.disassemble => {
            _ = try disassemble(&input_file);
        },
        Config.Mode.assemble => {},
    }
}

pub const OpCode = enum(u6) {
    mov = 0b100010,

    const OpCodeParseErr = error{
        unsupported_instruction,
    };

    pub fn tryFromStr(str: []const u8) OpCodeParseErr!OpCode {
        if (str.len < 3) {
            return OpCodeParseErr.unsupported_instruction;
        }

        if (std.mem.eql(u8, str[0..3], "mov")) {
            return OpCode.mov;
        }

        return OpCodeParseErr.unsupported_instruction;
    }

    pub fn tryFromBits(bits: u6) OpCodeParseErr!OpCode {
        if (std.meta.intToEnum(OpCode, bits)) |op| {
            return op;
        } else |_| {
            return OpCodeParseErr.unsupported_instruction;
        }
    }
};

pub fn parseArgs(args: []const []const u8) ConfigParseErr!Config {
    var app_mode: ?Config.Mode = null;
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

// De-construct a binary file into an assembly (textual representation) file
pub fn disassemble(input: *const std.fs.File) !OpCode {
    var buf: [1024]u8 = undefined;
    const bytes_read = try input.readAll(&buf);
    _ = bytes_read;

    const op_bits = buf[0] >> 2;
    const op = OpCode.tryFromBits(@intCast(op_bits)) catch |err| {
        std.debug.print("Bits {b} was not a supported instruction\n", .{op_bits});
        return err;
    };

    return op;
}

// Construct a binary file from an assembly (textual representation) file
pub fn assemble(input: *const std.fs.File) ![]const u8 {
    var buf: [1024]u8 = undefined;
    const bytes_read = try input.readAll(&buf);
    _ = bytes_read;
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
    try std.testing.expectEqual(Config.Mode.assemble, config.mode);
    try std.testing.expectEqualStrings("input.txt", config.input.?);
}

test "parser accepts valid disassemble config" {
    const test_args = [_][]const u8{ "program", "-d", "-i", "input.txt" };
    const config = try parseArgs(&test_args);
    try std.testing.expectEqual(Config.Mode.disassemble, config.mode);
    try std.testing.expectEqualStrings("input.txt", config.input.?);
}

test "parser accepts mode with no input (defaults to null)" {
    const test_args = [_][]const u8{ "program", "-a" };
    const config = try parseArgs(&test_args);
    try std.testing.expectEqual(Config.Mode.assemble, config.mode);
    try std.testing.expect(config.input == null);
}

test "can read a 6-bit integer into a supported opcode" {
    const mov_input: u6 = 0b100010;
    try std.testing.expectEqual(OpCode.mov, OpCode.tryFromBits(mov_input));

    const unsup_input: u6 = 0b111111;
    try std.testing.expectError(OpCode.OpCodeParseErr.unsupported_instruction, OpCode.tryFromBits(unsup_input));
}

test "can parse a `mov` instruction from its textual representation" {
    const mov_input = "mov cx,bx";
    try std.testing.expectEqual(OpCode.mov, OpCode.tryFromStr(mov_input));
}
