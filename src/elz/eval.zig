//! This module contains the core evaluation logic for the Element 0 interpreter.
//! It implements a tail-recursive evaluator for the language's syntax tree.

const std = @import("std");
const core = @import("core.zig");
const Value = core.Value;
const UserDefinedProc = core.UserDefinedProc;
const Environment = core.Environment;
const ElzError = @import("errors.zig").ElzError;

/// Evaluates a list of expressions.
fn eval_expr_list(list: Value, env: *Environment, fuel: *u64) !core.ValueList {
    var results = core.ValueList.init(env.allocator);
    var current_node = list;
    while (current_node != .nil) {
        const p = switch (current_node) {
            .pair => |pair_val| pair_val,
            else => return ElzError.InvalidArgument,
        };
        try results.append(try eval(&p.car, env, fuel));
        current_node = p.cdr;
    }
    return results;
}

/// Evaluates a procedure call.
pub fn eval_proc(proc: Value, args: core.ValueList, env: *Environment, fuel: *u64) anyerror!Value {
    switch (proc) {
        .closure => |c| {
            if (c.params.items.len != args.items.len) return ElzError.WrongArgumentCount;
            const new_env = try Environment.init(env.allocator, c.env);
            for (c.params.items, args.items) |param, arg| {
                try new_env.set(param.symbol, arg);
            }
            var result: Value = .nil;
            var current_node = c.body;
            while (current_node != .nil) {
                const p = switch (current_node) {
                    .pair => |pair_val| pair_val,
                    else => return ElzError.InvalidArgument,
                };
                result = try eval(&p.car, new_env, fuel);
                current_node = p.cdr;
            }
            return result;
        },
        .procedure => |p| return p(env, args),
        .foreign_procedure => |ff| return ff(env, args),
        else => return ElzError.NotAFunction,
    }
}

/// Evaluates an AST node in a given environment.
pub fn eval(ast_start: *const Value, env_start: *Environment, fuel: *u64) anyerror!Value {
    var current_ast = ast_start;
    var current_env = env_start;

    while (true) {
        if (fuel.* == 0) return ElzError.ExecutionBudgetExceeded;
        fuel.* -= 1;

        const ast = current_ast;
        const env = current_env;

        switch (ast.*) {
            .number, .boolean, .character, .nil, .closure, .procedure, .foreign_procedure, .opaque_pointer => return ast.*,
            .string => |s| return Value{ .string = try env.allocator.dupe(u8, s) },
            .symbol => |sym| return env.get(sym),
            .pair => |p| {
                const first = p.car;
                const rest = p.cdr;

                if (first.is_symbol("quote")) {
                    const p_arg = switch (rest) {
                        .pair => |p_rest| p_rest,
                        else => return ElzError.QuoteInvalidArguments,
                    };
                    if (p_arg.cdr != .nil) return ElzError.QuoteInvalidArguments;
                    return p_arg.car.deep_clone(env.allocator);
                }

                if (first.is_symbol("if")) {
                    const p_test = switch (rest) {
                        .pair => |p_rest| p_rest,
                        else => return ElzError.IfInvalidArguments,
                    };
                    const test_expr = p_test.car;
                    const p_consequent = switch (p_test.cdr) {
                        .pair => |p_rest| p_rest,
                        else => return ElzError.IfInvalidArguments,
                    };
                    const consequent_expr = p_consequent.car;
                    const condition = try eval(&test_expr, env, fuel);

                    const is_true = switch (condition) {
                        .boolean => |b| b,
                        else => true,
                    };

                    if (is_true) {
                        current_ast = &consequent_expr;
                        continue;
                    } else {
                        const p_alternative = switch (p_consequent.cdr) {
                            .pair => |p_rest| p_rest,
                            .nil => return Value.nil,
                            else => return ElzError.IfInvalidArguments,
                        };
                        if (p_alternative.cdr != .nil) return ElzError.IfInvalidArguments;
                        current_ast = &p_alternative.car;
                        continue;
                    }
                }

                if (first.is_symbol("or")) {
                    if (rest == .nil) return Value{ .boolean = false };
                    var current_node = rest;
                    while (current_node.pair.cdr != .nil) {
                        const result = try eval(&current_node.pair.car, env, fuel);
                        const is_true = switch (result) {
                            .boolean => |b| b,
                            else => true,
                        };
                        if (is_true) return result;
                        current_node = current_node.pair.cdr;
                    }
                    current_ast = &current_node.pair.car;
                    continue;
                }

                if (first.is_symbol("define")) {
                    const p_name = switch (rest) {
                        .pair => |p_rest| p_rest,
                        else => return ElzError.DefineInvalidArguments,
                    };
                    const name_or_sig = p_name.car;
                    const body = p_name.cdr;
                    switch (name_or_sig) {
                        .symbol => |symbol_name| {
                            const p_expr = switch (body) {
                                .pair => |p_rest| p_rest,
                                else => return ElzError.DefineInvalidArguments,
                            };
                            if (p_expr.cdr != .nil) return ElzError.DefineInvalidArguments;
                            const value = try eval(&p_expr.car, env, fuel);
                            try env.set(symbol_name, value);
                            return value;
                        },
                        .pair => |sig_pair| {
                            const fn_name_val = sig_pair.car;
                            const fn_name = if (fn_name_val == .symbol) fn_name_val.symbol else return ElzError.DefineInvalidSymbol;
                            const params = sig_pair.cdr;
                            var params_list_gc = core.ValueList.init(env.allocator);
                            var current_param = params;
                            while (current_param != .nil) {
                                const param_p = switch (current_param) {
                                    .pair => |pp| pp,
                                    else => return ElzError.LambdaInvalidParams,
                                };
                                if (param_p.car != .symbol) return ElzError.LambdaInvalidParams;
                                try params_list_gc.append(param_p.car);
                                current_param = param_p.cdr;
                            }
                            const proc = try env.allocator.create(UserDefinedProc);
                            proc.* = .{ .params = params_list_gc, .body = try body.deep_clone(env.allocator), .env = env };
                            const closure = Value{ .closure = proc };
                            try env.set(fn_name, closure);
                            return closure;
                        },
                        else => return ElzError.DefineInvalidSymbol,
                    }
                }

                if (first.is_symbol("set!")) {
                    const p_sym = switch (rest) {
                        .pair => |p_rest| p_rest,
                        else => return ElzError.SetInvalidArguments,
                    };
                    const symbol = p_sym.car;
                    if (symbol != .symbol) return ElzError.SetInvalidSymbol;
                    const p_expr = switch (p_sym.cdr) {
                        .pair => |p_rest| p_rest,
                        else => return ElzError.SetInvalidArguments,
                    };
                    if (p_expr.cdr != .nil) return ElzError.SetInvalidArguments;
                    const value = try eval(&p_expr.car, env, fuel);
                    try env.update(symbol.symbol, value);
                    return Value.nil;
                }

                if (first.is_symbol("lambda")) {
                    const p_formals = switch (rest) {
                        .pair => |p_rest| p_rest,
                        else => return ElzError.LambdaInvalidArguments,
                    };
                    const params_list = p_formals.car;
                    const body = p_formals.cdr;
                    if (body == .nil) return ElzError.LambdaInvalidArguments;
                    var params_list_gc = core.ValueList.init(env.allocator);
                    var current_param = params_list;
                    while (current_param != .nil) {
                        const param_p = switch (current_param) {
                            .pair => |pp| pp,
                            else => return ElzError.LambdaInvalidParams,
                        };
                        if (param_p.car != .symbol) return ElzError.LambdaInvalidParams;
                        try params_list_gc.append(param_p.car);
                        current_param = param_p.cdr;
                    }
                    const proc = try env.allocator.create(UserDefinedProc);
                    proc.* = .{ .params = params_list_gc, .body = try body.deep_clone(env.allocator), .env = env };
                    return Value{ .closure = proc };
                }

                if (first.is_symbol("begin")) {
                    var current_node = rest;
                    if (current_node == .nil) return .nil;
                    while (current_node.pair.cdr != .nil) {
                        _ = try eval(&current_node.pair.car, env, fuel);
                        current_node = current_node.pair.cdr;
                    }
                    current_ast = &current_node.pair.car;
                    continue;
                }

                if (first.is_symbol("let") or first.is_symbol("let*")) {
                    const is_let_star = first.is_symbol("let*");
                    const p_bindings = switch (rest) {
                        .pair => |p_rest| p_rest,
                        else => return ElzError.InvalidArgument,
                    };
                    const bindings_list = p_bindings.car;
                    const body = p_bindings.cdr;
                    const new_env = try Environment.init(env.allocator, env);
                    var current_binding = bindings_list;
                    while (current_binding != .nil) {
                        const binding_p = switch (current_binding) {
                            .pair => |p_rest| p_rest,
                            else => return ElzError.InvalidArgument,
                        };
                        const binding = binding_p.car;
                        const var_p = switch (binding) {
                            .pair => |p_rest| p_rest,
                            else => return ElzError.InvalidArgument,
                        };
                        const var_sym = var_p.car;
                        if (var_sym != .symbol) return ElzError.InvalidArgument;
                        const init_p = switch (var_p.cdr) {
                            .pair => |p_rest| p_rest,
                            else => return ElzError.InvalidArgument,
                        };
                        const init_expr = init_p.car;
                        const eval_env = if (is_let_star) new_env else env;
                        const value = try eval(&init_expr, eval_env, fuel);
                        try new_env.set(var_sym.symbol, value);
                        current_binding = binding_p.cdr;
                    }

                    var current_body_node = body;
                    if (current_body_node == .nil) return .nil;
                    while (current_body_node.pair.cdr != .nil) {
                        _ = try eval(&current_body_node.pair.car, new_env, fuel);
                        current_body_node = current_body_node.pair.cdr;
                    }
                    current_ast = &current_body_node.pair.car;
                    current_env = new_env;
                    continue;
                }

                if (first.is_symbol("letrec")) {
                    const p_bindings = switch (rest) {
                        .pair => |p_rest| p_rest,
                        else => return ElzError.InvalidArgument,
                    };
                    const bindings_list = p_bindings.car;
                    const body = p_bindings.cdr;
                    const new_env = try Environment.init(env.allocator, env);
                    var var_symbols = std.ArrayList(Value).init(env.allocator);
                    defer var_symbols.deinit();
                    var inits = std.ArrayList(Value).init(env.allocator);
                    defer inits.deinit();
                    var current_binding_node = bindings_list;
                    while (current_binding_node != .nil) {
                        const binding_pair = switch (current_binding_node) {
                            .pair => |p_rest| p_rest,
                            else => return ElzError.InvalidArgument,
                        };
                        const binding = binding_pair.car;
                        const binding_def_pair = switch (binding) {
                            .pair => |p_rest| p_rest,
                            else => return ElzError.InvalidArgument,
                        };
                        const var_sym = binding_def_pair.car;
                        if (var_sym != .symbol) return ElzError.InvalidArgument;
                        const init_pair = switch (binding_def_pair.cdr) {
                            .pair => |p_rest| p_rest,
                            else => return ElzError.InvalidArgument,
                        };
                        const init = init_pair.car;
                        try var_symbols.append(var_sym);
                        try inits.append(init);
                        try new_env.set(var_sym.symbol, .nil);
                        current_binding_node = binding_pair.cdr;
                    }
                    for (var_symbols.items, inits.items) |var_sym, init| {
                        const value = try eval(&init, new_env, fuel);
                        try new_env.update(var_sym.symbol, value);
                    }

                    var current_body_node = body;
                    if (current_body_node == .nil) return .nil;
                    while (current_body_node.pair.cdr != .nil) {
                        _ = try eval(&current_body_node.pair.car, new_env, fuel);
                        current_body_node = current_body_node.pair.cdr;
                    }
                    current_ast = &current_body_node.pair.car;
                    current_env = new_env;
                    continue;
                }

                const proc_val = try eval(&first, env, fuel);
                const arg_vals = try eval_expr_list(rest, env, fuel);

                switch (proc_val) {
                    .closure => |c| {
                        if (c.params.items.len != arg_vals.items.len) return ElzError.WrongArgumentCount;
                        const new_env = try Environment.init(env.allocator, c.env);
                        for (c.params.items, arg_vals.items) |param, arg| {
                            try new_env.set(param.symbol, arg);
                        }

                        var current_node = c.body;
                        if (current_node == .nil) return .nil;
                        while (current_node.pair.cdr != .nil) {
                            _ = try eval(&current_node.pair.car, new_env, fuel);
                            current_node = current_node.pair.cdr;
                        }
                        current_ast = &current_node.pair.car;
                        current_env = new_env;
                        continue;
                    },
                    .procedure => |prim| return prim(env, arg_vals),
                    .foreign_procedure => |ff| return ff(env, arg_vals),
                    else => return ElzError.NotAFunction,
                }
            },
        }
    }
}
