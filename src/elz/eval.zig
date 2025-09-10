const std = @import("std");
const core = @import("core.zig");
const Value = core.Value;
const UserDefinedProc = core.UserDefinedProc;
const Environment = core.Environment;
const ElzError = @import("errors.zig").ElzError;
const interpreter = @import("interpreter.zig");

fn eval_expr_list(interp: *interpreter.Interpreter, list: Value, env: *Environment, fuel: *u64) ElzError!core.ValueList {
    var results = core.ValueList.init(env.allocator);
    var current_node = list;
    while (current_node != .nil) {
        const p = switch (current_node) {
            .pair => |pair_val| pair_val,
            else => return ElzError.InvalidArgument,
        };
        try results.append(try eval(interp, &p.car, env, fuel));
        current_node = p.cdr;
    }
    return results;
}

pub fn eval_proc(interp: *interpreter.Interpreter, proc: Value, args: core.ValueList, env: *Environment, fuel: *u64) ElzError!Value {
    switch (proc) {
        .closure => |c| {
            if (c.params.items.len != args.items.len) return ElzError.WrongArgumentCount;
            const new_env = try Environment.init(env.allocator, c.env);
            for (c.params.items, args.items) |param, arg| {
                try new_env.set(interp, param.symbol, arg);
            }
            var result: Value = .nil;
            var current_node = c.body;
            while (current_node != .nil) {
                const p = switch (current_node) {
                    .pair => |pair_val| pair_val,
                    else => return ElzError.InvalidArgument,
                };
                result = try eval(interp, &p.car, new_env, fuel);
                current_node = p.cdr;
            }
            return result;
        },
        .procedure => |p| return p(interp, env, args),
        .foreign_procedure => |ff| {
            return ff(env, args) catch |err| {
                interp.last_error_message = @errorName(err);
                return ElzError.ForeignFunctionError;
            };
        },
        else => return ElzError.NotAFunction,
    }
}

pub fn eval(interp: *interpreter.Interpreter, ast_start: *const Value, env_start: *Environment, fuel: *u64) ElzError!Value {
    var current_ast = ast_start;
    var current_env = env_start;

    while (true) {
        interp.last_error_message = null;
        if (fuel.* == 0) return ElzError.ExecutionBudgetExceeded;
        fuel.* -= 1;

        const ast = current_ast;
        const env = current_env;

        switch (ast.*) {
            .number, .boolean, .character, .nil, .closure, .procedure, .foreign_procedure, .opaque_pointer, .cell, .unspecified => return ast.*,
            .string => |s| return Value{ .string = try env.allocator.dupe(u8, s) },
            .symbol => |sym| return env.get(sym, interp),
            .pair => |p| {
                const first = p.car;
                const rest = p.cdr;

                if (first.is_symbol("quote")) {
                    const p_arg = switch (rest) {
                        .pair => |p_rest| p_rest,
                        else => return ElzError.QuoteInvalidArguments,
                    };
                    if (p_arg.cdr != .nil) return ElzError.QuoteInvalidArguments;
                    return try p_arg.car.deep_clone(env.allocator);
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
                    const condition = try eval(interp, &test_expr, env, fuel);

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

                if (first.is_symbol("cond")) {
                    var current_clause_node = rest;
                    while (current_clause_node != .nil) {
                        const clause_pair = switch (current_clause_node) {
                            .pair => |cp| cp,
                            else => return ElzError.InvalidArgument,
                        };
                        const clause = clause_pair.car;
                        const clause_p = switch (clause) {
                            .pair => |cp| cp,
                            else => return ElzError.InvalidArgument,
                        };
                        const test_expr = clause_p.car;
                        if (test_expr.is_symbol("else")) {
                            const body = clause_p.cdr;
                            if (body == .nil) return ElzError.InvalidArgument;
                            var current_body_node = body;
                            while (current_body_node.pair.cdr != .nil) {
                                _ = try eval(interp, &current_body_node.pair.car, env, fuel);
                                current_body_node = current_body_node.pair.cdr;
                            }
                            current_ast = &current_body_node.pair.car;
                            continue;
                        }
                        const condition = try eval(interp, &test_expr, env, fuel);
                        const is_true = switch (condition) {
                            .boolean => |b| b,
                            else => true,
                        };
                        if (is_true) {
                            const body = clause_p.cdr;
                            if (body == .nil) return condition;
                            var current_body_node = body;
                            while (current_body_node.pair.cdr != .nil) {
                                _ = try eval(interp, &current_body_node.pair.car, env, fuel);
                                current_body_node = current_body_node.pair.cdr;
                            }
                            current_ast = &current_body_node.pair.car;
                            continue;
                        }
                        current_clause_node = clause_pair.cdr;
                    }
                    return Value.nil;
                }

                if (first.is_symbol("and")) {
                    if (rest == .nil) return Value{ .boolean = true };
                    var current_node = rest;
                    while (current_node.pair.cdr != .nil) {
                        const result = try eval(interp, &current_node.pair.car, env, fuel);
                        const is_true = switch (result) {
                            .boolean => |b| b,
                            else => true,
                        };
                        if (!is_true) return result;
                        current_node = current_node.pair.cdr;
                    }
                    current_ast = &current_node.pair.car;
                    continue;
                }

                if (first.is_symbol("or")) {
                    if (rest == .nil) return Value{ .boolean = false };
                    var current_node = rest;
                    while (current_node.pair.cdr != .nil) {
                        const result = try eval(interp, &current_node.pair.car, env, fuel);
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
                            const value = try eval(interp, &p_expr.car, env, fuel);
                            try env.set(interp, symbol_name, value);
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
                            try env.set(interp, fn_name, closure);
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
                    const value = try eval(interp, &p_expr.car, env, fuel);
                    try env.update(interp, symbol.symbol, value);
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
                        _ = try eval(interp, &current_node.pair.car, env, fuel);
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
                        const value = try eval(interp, &init_expr, eval_env, fuel);
                        try new_env.set(interp, var_sym.symbol, value);
                        current_binding = binding_p.cdr;
                    }

                    var current_body_node = body;
                    if (current_body_node == .nil) return .nil;
                    while (current_body_node.pair.cdr != .nil) {
                        _ = try eval(interp, &current_body_node.pair.car, new_env, fuel);
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

                    var cells = std.ArrayList(*core.Cell).init(env.allocator);
                    defer cells.deinit();
                    var inits = std.ArrayList(Value).init(env.allocator);
                    defer inits.deinit();

                    var node1 = bindings_list;
                    while (node1 != .nil) {
                        const binding_pair = switch (node1) {
                            .pair => |pp| pp,
                            else => return ElzError.InvalidArgument,
                        };
                        const binding = binding_pair.car;
                        const var_pair = switch (binding) {
                            .pair => |pp| pp,
                            else => return ElzError.InvalidArgument,
                        };
                        const var_sym = var_pair.car;
                        if (var_sym != .symbol) return ElzError.InvalidArgument;
                        const init_pair = switch (var_pair.cdr) {
                            .pair => |pp| pp,
                            else => return ElzError.InvalidArgument,
                        };

                        const cell = try env.allocator.create(core.Cell);
                        cell.* = .{ .content = .unspecified };
                        try new_env.set(interp, var_sym.symbol, Value{ .cell = cell });
                        try cells.append(cell);
                        try inits.append(init_pair.car);

                        node1 = binding_pair.cdr;
                    }

                    for (cells.items, inits.items) |cell, init| {
                        const value = try eval(interp, &init, new_env, fuel);
                        cell.content = value;
                    }

                    var current_body_node = body;
                    if (current_body_node == .nil) return .nil;
                    while (current_body_node.pair.cdr != .nil) {
                        _ = try eval(interp, &current_body_node.pair.car, new_env, fuel);
                        current_body_node = current_body_node.pair.cdr;
                    }
                    current_ast = &current_body_node.pair.car;
                    current_env = new_env;
                    continue;
                }

                if (first.is_symbol("try")) {
                    var try_body_forms = std.ArrayList(core.Value).init(env.allocator);
                    defer try_body_forms.deinit();
                    var catch_clause: ?core.Value = null;
                    var current_node = rest;
                    while (current_node != .nil) {
                        const node_p = switch (current_node) {
                            .pair => |pair_val| pair_val,
                            else => return ElzError.InvalidArgument,
                        };
                        const form = node_p.car;
                        if (form == .pair and form.pair.car.is_symbol("catch")) {
                            catch_clause = form;
                            break;
                        }
                        try try_body_forms.append(form);
                        current_node = node_p.cdr;
                    }

                    if (catch_clause == null) {
                        return ElzError.InvalidArgument;
                    }

                    const catch_p = catch_clause.?.pair;
                    const catch_args_p = switch (catch_p.cdr) {
                        .pair => |pair_val| pair_val,
                        else => return ElzError.InvalidArgument,
                    };

                    const err_symbol = catch_args_p.car;
                    if (err_symbol != .symbol) {
                        return ElzError.InvalidArgument;
                    }
                    const handler_body = catch_args_p.cdr;
                    if (handler_body == .nil) {
                        return ElzError.InvalidArgument;
                    }

                    var last_result: core.Value = .unspecified;
                    var eval_error: ?ElzError = null;
                    for (try_body_forms.items) |form| {
                        last_result = eval(interp, &form, env, fuel) catch |err| {
                            eval_error = err;
                            break;
                        };
                    }

                    if (eval_error) |_| {
                        const new_env = try Environment.init(env.allocator, env);
                        const msg = interp.last_error_message orelse "An unknown error occurred.";
                        const err_val = try Value.from(env.allocator, msg);
                        try new_env.set(interp, err_symbol.symbol, err_val);
                        var current_handler_node = handler_body;
                        var handler_result: core.Value = .unspecified;
                        while (current_handler_node != .nil) {
                            const handler_p = current_handler_node.pair;
                            handler_result = try eval(interp, &handler_p.car, new_env, fuel);
                            current_handler_node = handler_p.cdr;
                        }
                        return handler_result;
                    } else {
                        return last_result;
                    }
                }

                const proc_val = try eval(interp, &first, env, fuel);
                const arg_vals = try eval_expr_list(interp, rest, env, fuel);

                switch (proc_val) {
                    .closure => |c| {
                        if (c.params.items.len != arg_vals.items.len) return ElzError.WrongArgumentCount;

                        var call_env = c.env;
                        if (c.params.items.len > 0) {
                            const new_env = try Environment.init(env.allocator, c.env);
                            for (c.params.items, arg_vals.items) |param, arg| {
                                try new_env.set(interp, param.symbol, arg);
                            }
                            call_env = new_env;
                        }

                        var body_node = c.body;
                        if (body_node == .nil) return .nil;

                        while (body_node.pair.cdr != .nil) {
                            _ = try eval(interp, &body_node.pair.car, call_env, fuel);
                            body_node = body_node.pair.cdr;
                        }

                        current_env = call_env;
                        current_ast = &body_node.pair.car;
                        continue;
                    },
                    .procedure => |prim| return prim(interp, env, arg_vals),
                    .foreign_procedure => |ff| {
                        return ff(env, arg_vals) catch |err| {
                            interp.last_error_message = @errorName(err);
                            return ElzError.ForeignFunctionError;
                        };
                    },
                    else => return ElzError.NotAFunction,
                }
            },
        }
    }
}
