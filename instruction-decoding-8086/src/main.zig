const std = @import("std");

const Cfg = struct {
    file_path: *const []u8,
    mode: AppMode = .disassemble,

    const AppMode = enum { disassemble, assemble };

    // TODO - Return an error union
    pub fn fromArgs(args: **[][]u8) Cfg {
        const Allowed = enum {
            // TODO
        };

        const x = undefined;

        for (args, 0..) |arg, i| {
            switch (arg) {
                "-f" => {
                    std.debug.print("Found -f");
                }
            }
        }

        const result = Cfg{
            // TODO
        };

        return result;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();

    // Read command line args to look for input file
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    try stdout.print("Number of arguments: {d}\n", .{args.len});
    for (args, 0..) |arg, i| {
        try stdout.print("Argument {d}: {s}\n", .{ i, arg });
    }
    // TODO
    const cfg = Cfg.fromArgs(args);
    _ = cfg;

    try stdout.print("\n", .{});

    // Check if a filename was provided as argument
    const filename = if (args.len > 1) args[1] else "input.asm";
    try stdout.print("Using file: {s}\n\n", .{filename});

    // Open file and get stats
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const stat = try file.stat();
    try stdout.print("File size: {d} bytes\n", .{stat.size});
    try stdout.print("Creation time: {d}\n", .{stat.ctime});
    try stdout.print("Last access time: {d}\n", .{stat.atime});
    try stdout.print("Last modification time: {d}\n", .{stat.mtime});

    // Read entire file as text
    // const content = try file.readToEndAlloc(allocator, stat.size);
    // defer allocator.free(content);
    // try stdout.print("\nFile contents as text:\n{s}\n", .{content});

    // Read file as binary
    try file.seekTo(0); // Reset file position to beginning
    var buffer: [1024]u8 = undefined;
    const bytes_read = try file.readAll(&buffer);

    try stdout.print("\nFirst 16 bytes as hex:\n", .{});
    for (buffer[0..@min(16, bytes_read)]) |byte| {
        try stdout.print("{X:0>2} ", .{byte});
    }
    try stdout.print("\n", .{});
}

fn disassemble(f: *std.fs.File) !void {
    _ = f;
}
