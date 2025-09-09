const std = @import("std");
const elz = @import("elz");
const chilli = @import("chilli");

const linenoise = @cImport({
    @cInclude("linenoise.h");
});

// Zig

// A helper function to display a Value with special handling for strings.
// It prints strings without quotes and appends a newline if not already present.
// For all other values, it uses the existing elz.write function and appends a newline.
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

/// Executes a string of Element 0 source code.
/// This function parses and evaluates the source code.
/// It prints the result of the last evaluated expression.
///
/// - `interpreter`: A pointer to the interpreter instance.
/// - `source`: The source code to execute.
fn exec(interpreter: *elz.Interpreter, source: []const u8) !void {
    const forms = try elz.parser.readAll(source, interpreter.allocator);
    if (forms.items.len == 0) return;

    var last_result: elz.Value = .nil;
    for (forms.items) |form| {
        var fuel: u64 = 1_000_000;
        last_result = elz.eval.eval(&form, interpreter.root_env, &fuel) catch |err| {
            const stdout = std.io.getStdOut().writer();
            try stdout.print("Error evaluating form: ", .{});
            elz.write(form, stdout) catch {};
            try stdout.print("\nError: {s}\n", .{@errorName(err)});
            return err;
        };
    }

    const stdout = std.io.getStdOut().writer();
    if (last_result != .unspecified) {
        try displayValue(interpreter, last_result, stdout);
    }
}

/// Starts the Read-Eval-Print-Loop (REPL).
/// This function provides an interactive prompt for the user.
/// It reads expressions, evaluates them, and prints the results.
///
/// - `interpreter`: A pointer to the interpreter instance.
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
                last_result = elz.eval.eval(&form, interpreter.root_env, &fuel) catch |err| {
                    const stdout = std.io.getStdOut().writer();
                    try stdout.print("Runtime Error: {s}\n", .{@errorName(err)});
                    break :eval_line;
                };
            }
            const stdout = std.io.getStdOut().writer();
            // Only print the result if it is not the special 'unspecified' value.
            if (last_result != .unspecified) {
                try displayValue(interpreter, last_result, stdout);
            }
        }
    }
}

/// The execution entry point for the root command.
/// This function determines whether to execute a file or start the REPL.
/// It is called by the chilli command-line parser.
///
/// - `ctx`: The command context from the chilli library.
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

/// The main function for the Element 0 interpreter executable.
/// This function initializes the interpreter and the command-line interface.
/// It then runs the root command.
pub fn main() anyerror!void {
    var interpreter = try elz.Interpreter.init(.{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var root_cmd = try chilli.Command.init(gpa.allocator(), .{
        .name = "elz",
        .description = "A Lisp dialect implemented in Zig",
        .version = "0.1.0",
        .exec = rootExec,
    });
    defer root_cmd.deinit();

    try root_cmd.addFlag(.{
        .name = "file",
        .shortcut = 'f',
        .description = "The file to evaluate",
        .type = .String,
        .default_value = .{ .String = "" },
    });

    try root_cmd.run(&interpreter);
}
