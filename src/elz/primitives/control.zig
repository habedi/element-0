//! This module implements control-related primitive procedures.

const std = @import("std");
const core = @import("../core.zig");
const ElzError = @import("../errors.zig").ElzError;

/// The `apply` primitive procedure.
/// This function is not yet implemented.
///
/// - `env`: The environment.
/// - `args`: The arguments to the procedure.
/// - `return`: An error indicating that the function is not implemented.
pub fn apply(_: *core.Environment, _: core.ValueList) !core.Value {
    return ElzError.NotImplemented;
}
