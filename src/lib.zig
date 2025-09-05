//! This module exposes the public API of the Element 0 interpreter (Elz) as a Zig library.
//! It re-exports main components from various internal modules.
//! This should make it easy to use the interpreter in other Zig projects.

pub const core = @import("elz/core.zig");
pub const ElzError = @import("elz/errors.zig").ElzError;
pub const eval = @import("elz/eval.zig");
pub const write = @import("elz/writer.zig").write;
pub const ffi = @import("elz/ffi.zig");
pub const env_setup = @import("elz/env_setup.zig");
pub const interpreter = @import("elz/interpreter.zig");
pub const errors = @import("elz/errors.zig");
pub const parser = @import("elz/parser.zig");

pub const Value = core.Value;
pub const Environment = core.Environment;
pub const UserDefinedProc = core.UserDefinedProc;
pub const PrimitiveFn = core.PrimitiveFn;
pub const Interpreter = interpreter.Interpreter;
pub const SandboxFlags = interpreter.SandboxFlags;
