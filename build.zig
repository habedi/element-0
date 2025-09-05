const std = @import("std");
const fs = std.fs;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // --- GC dependency ---
    const gc = b.addStaticLibrary(.{
        .name = "gc",
        .target = target,
        .optimize = optimize,
    });
    {

        // Flags for compiling BDWGC
        var cflags: std.ArrayListUnmanaged([]const u8) = .empty;
        defer cflags.deinit(b.allocator);

        // Always enable NO_EXECUTE_PERMISSION
        cflags.append(b.allocator, "-DNO_EXECUTE_PERMISSION") catch unreachable;

        // enable GC debug/assertions when environment variable `GC_DEBUG` is set and not "0"
        const gc_debug_enabled = blk: {
            const env_value = std.posix.getenv("GC_DEBUG") orelse break :blk false;
            break :blk std.mem.eql(u8, env_value, "1") or std.mem.eql(u8, env_value, "true");
        };

        if (gc_debug_enabled) {
            cflags.append(b.allocator, "-DGC_DEBUG") catch unreachable;
            cflags.append(b.allocator, "-DGC_ASSERTIONS") catch unreachable;
        }

        const libgc_srcs = &[_][]const u8{
            "alloc.c",
            "reclaim.c",
            "allchblk.c",
            "misc.c",
            "mach_dep.c",
            "os_dep.c",
            "mark_rts.c",
            "headers.c",
            "mark.c",
            "blacklst.c",
            "finalize.c",
            "new_hblk.c",
            "dbg_mlc.c",
            "malloc.c",
            "dyn_load.c",
            "typd_mlc.c",
            "ptr_chck.c",
            "mallocx.c",
        };

        gc.linkLibC();
        gc.addIncludePath(b.path("external/bdwgc/include"));
        for (libgc_srcs) |src| {
            const src_path = b.fmt("external/bdwgc/{s}", .{src});
            gc.addCSourceFile(.{ .file = b.path(src_path), .flags = cflags.items });
        }
    }

    // --- Library Setup ---
    const lib_source = b.path("src/lib.zig");

    const lib_module = b.addModule("elz", .{
        .root_source_file = lib_source,
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .name = "elz",
        .root_module = lib_module,
    });
    lib.addIncludePath(b.path("external/bdwgc/include"));
    lib.linkLibrary(gc);
    lib.linkSystemLibrary("c");
    b.installArtifact(lib);

    // --- REPL Executable ---
    const repl_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    repl_module.addImport("elz", lib_module);

    const repl_exe = b.addExecutable(.{
        .name = "elz-repl",
        .root_module = repl_module,
    });

    // --- Linenoise dependency ---
    const linenoise_flags = &[_][]const u8{};
    const linenoise_includes = "external/linenoise";
    const linenoise_sources = &[_][]const u8{
        "external/linenoise/linenoise.c",
    };
    repl_exe.addIncludePath(b.path(linenoise_includes));
    repl_exe.addCSourceFiles(.{
        .files = linenoise_sources,
        .flags = linenoise_flags,
    });
    repl_exe.linkSystemLibrary("c");

    // Add dependency on 'chilli' library
    const chilli_dep = b.dependency("chilli", .{});
    const chilli_module = b.createModule(.{ .root_source_file = chilli_dep.path("src/lib.zig") });
    repl_exe.root_module.addImport("chilli", chilli_module);

    b.installArtifact(repl_exe);

    const run_repl_cmd = b.addRunArtifact(repl_exe);
    const run_repl_step = b.step("repl", "Run the REPL");
    run_repl_step.dependOn(&run_repl_cmd.step);

    // --- Docs Setup ---
    const docs_step = b.step("docs", "Generate API documentation");
    const doc_install_path = "docs/api";

    const gen_docs_cmd = b.addSystemCommand(&[_][]const u8{
        b.graph.zig_exe,
        "build-lib",
        "src/lib.zig",
        "-femit-docs=" ++ doc_install_path,
    });

    const mkdir_cmd = b.addSystemCommand(&[_][]const u8{
        "mkdir", "-p", doc_install_path,
    });
    gen_docs_cmd.step.dependOn(&mkdir_cmd.step);

    docs_step.dependOn(&gen_docs_cmd.step);

    // --- Test Setup ---
    const test_module = b.createModule(.{
        .root_source_file = lib_source,
        .target = target,
        .optimize = optimize,
    });

    const lib_unit_tests = b.addTest(.{
        .root_module = test_module,
    });
    lib_unit_tests.addIncludePath(b.path("external/bdwgc/include"));
    lib_unit_tests.linkLibrary(gc);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // --- Example Setup ---
    const examples_path = "examples/zig";
    var examples_dir = fs.cwd().openDir(examples_path, .{ .iterate = true }) catch |err| {
        if (err == error.FileNotFound) return;
        @panic("Can't open 'examples/zig' directory");
    };
    defer examples_dir.close();

    var dir_iter = examples_dir.iterate();
    while (dir_iter.next() catch @panic("Failed to iterate examples")) |entry| {
        if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;

        const exe_name = fs.path.stem(entry.name);
        const exe_path = b.fmt("{s}/{s}", .{ examples_path, entry.name });

        const exe_module = b.createModule(.{
            .root_source_file = b.path(exe_path),
            .target = target,
            .optimize = optimize,
        });
        exe_module.addImport("elz", lib_module);

        const exe = b.addExecutable(.{
            .name = exe_name,
            .root_module = exe_module,
        });
        exe.linkSystemLibrary("c");
        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        const run_step_name = b.fmt("run-{s}", .{exe_name});
        const run_step_desc = b.fmt("Run the {s} example", .{exe_name});
        const run_step = b.step(run_step_name, run_step_desc);
        run_step.dependOn(&run_cmd.step);
    }
}
