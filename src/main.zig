const std = @import("std");
const elz = @import("elz");
const chilli = @import("chilli");

const linenoise = @cImport({
    @cInclude("linenoise.h");
});

fn displayValue(_: *elz.Interpreter, value: elz.Value, writer: anytype) !void {
    switch (value) {
        .string => |s| {
            try writer.writeAll(s);
            if (s.len == 0 or s[s.len - 1] != '\n') {
                try writer.writeAll("\n");
            }
        },
        else => {
            try elz.write(value, writer);
            try writer.writeAll("\n");
        },
    }
}

fn exec(interpreter: *elz.Interpreter, source: []const u8) !void {
    const forms = elz.parser.readAll(source, interpreter.allocator) catch |err| {
        std.debug.print("Parse Error: {s}\n", .{@errorName(err)});
        return err;
    };
    if (forms.items.len == 0) return;

    var last_result: elz.Value = .nil;
    for (forms.items) |form| {
        var fuel: u64 = 1_000_000;
        last_result = elz.eval.eval(interpreter, &form, interpreter.root_env, &fuel) catch |err| {
            const stdout = std.io.getStdOut().writer();
            try stdout.print("--- Runtime Error ---\n", .{});
            if (interpreter.last_error_message) |msg| {
                try stdout.print("Message: {s}\n", .{msg});
            } else {
                try stdout.print("Error: {s}\n", .{@errorName(err)});
            }
            try stdout.print("In form: ", .{});
            try elz.write(form, stdout);
            try stdout.print("\n", .{});
            return;
        };
    }

    const stdout = std.io.getStdOut().writer();
    if (last_result != .unspecified) {
        try displayValue(interpreter, last_result, stdout);
    }
}

fn repl(interpreter: *elz.Interpreter) !void {
    const history_path = "history.txt";
    _ = linenoise.linenoiseHistoryLoad(history_path);
    defer {
        _ = linenoise.linenoiseHistorySave(history_path);
    }

    while (true) {
        const line = linenoise.linenoise("> ");
        if (line == null) {
            return;
        }
        defer linenoise.linenoiseFree(line);

        const line_slice = std.mem.sliceTo(line, 0);

        if (line_slice.len == 0) {
            continue;
        }

        if (std.mem.eql(u8, line_slice, ".exit")) {
            return;
        }

        _ = linenoise.linenoiseHistoryAdd(line);

        eval_line: {
            const forms = elz.parser.readAll(line_slice, interpreter.allocator) catch |err| {
                const stdout = std.io.getStdOut().writer();
                try stdout.print("Parse Error: {s}\n", .{@errorName(err)});
                break :eval_line;
            };

            if (forms.items.len == 0) break :eval_line;

            var last_result: elz.Value = .nil;
            for (forms.items) |form| {
                var fuel: u64 = 1_000_000;
                last_result = elz.eval.eval(interpreter, &form, interpreter.root_env, &fuel) catch |err| {
                    const stdout = std.io.getStdOut().writer();
                    if (interpreter.last_error_message) |msg| {
                        try stdout.print("Error: {s}\n", .{msg});
                    } else {
                        try stdout.print("Error: {s}\n", .{@errorName(err)});
                    }
                    break :eval_line;
                };
            }
            const stdout = std.io.getStdOut().writer();
            if (last_result != .unspecified) {
                try displayValue(interpreter, last_result, stdout);
            }
        }
    }
}

fn rootExec(ctx: chilli.CommandContext) !void {
    const interpreter = ctx.getContextData(elz.Interpreter).?;

    if (ctx.command.getFlagValue("file")) |flag_value| {
        if (flag_value.String.len > 0) {
            const filename = flag_value.String;
            const file = try std.fs.cwd().openFile(filename, .{});
            defer file.close();

            const source = try file.readToEndAlloc(interpreter.allocator, 1024 * 1024);
            defer interpreter.allocator.free(source);

            try exec(interpreter, source);
            return;
        }
    }

    try repl(interpreter);
}

/// The main entry point for the `elz` executable.
/// This function initializes the interpreter and the command-line interface.
/// It can either start a REPL or execute a source file, based on the command-line arguments.
pub fn main() anyerror!void {
    var interpreter = try elz.Interpreter.init(.{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var root_cmd = try chilli.Command.init(gpa.allocator(), .{
        .name = "elz",
        .description = "An Element 0 dialect implemented in Zig λ",
        .version = "0.1.0-alpha.2",
        .exec = rootExec,
    });
    defer root_cmd.deinit();

    try root_cmd.addFlag(.{
        .name = "file",
        .shortcut = 'f',
        .description = "The Element 0 source file to execute",
        .type = .String,
        .default_value = .{ .String = "" },
    });

    try root_cmd.run(&interpreter);
}
