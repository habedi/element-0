//! This module is responsible for parsing Element 0 source code.
//! It includes a tokenizer and a parser that builds an abstract syntax tree (AST).

const std = @import("std");
const core = @import("core.zig");
const Value = core.Value;
const ElzError = @import("errors.zig").ElzError;

/// Tokenizes a string of Element 0 source code.
///
/// - `source`: The source code to tokenize.
/// - `allocator`: The memory allocator to use.
/// - `return`: An `ArrayList` of tokens.
fn tokenize(source: []const u8, allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
    var tokens = std.ArrayList([]const u8).init(allocator);
    errdefer tokens.deinit();
    var i: usize = 0;
    while (i < source.len) {
        const char = source[i];
        switch (char) {
            ';' => { // Handle comments
                while (i < source.len and source[i] != '\n') {
                    i += 1;
                }
            },
            ' ', '\t', '\r', '\n' => i += 1,
            '(', ')', '\'' => {
                try tokens.append(source[i .. i + 1]);
                i += 1;
            },
            '"' => {
                var j = i + 1;
                while (j < source.len and source[j] != '"') {
                    if (source[j] == '\\' and j + 1 < source.len) {
                        j += 2;
                    } else {
                        j += 1;
                    }
                }
                if (j >= source.len) return ElzError.UnterminatedString;
                try tokens.append(source[i .. j + 1]);
                i = j + 1;
            },
            else => {
                var j = i;
                while (j < source.len and !std.ascii.isWhitespace(source[j]) and source[j] != '(' and source[j] != ')' and source[j] != '\'' and source[j] != ';') {
                    j += 1;
                }
                try tokens.append(source[i..j]);
                i = j;
            },
        }
    }
    return tokens;
}

/// The parser for Element 0 source code.
/// It holds the state of the parsing process.
const Parser = struct {
    tokens: std.ArrayList([]const u8),
    position: usize,
    allocator: std.mem.Allocator,

    /// Parses a single form from the token stream.
    ///
    /// - `self`: A pointer to the parser.
    /// - `return`: The parsed `Value`.
    fn parse_form(self: *Parser) ElzError!Value {
        if (self.position >= self.tokens.items.len) return ElzError.UnexpectedEndOfInput;
        const token = self.tokens.items[self.position];
        self.position += 1;
        if (std.mem.eql(u8, token, "'")) {
            const next_form = try self.parse_form();
            const quote_symbol = Value{ .symbol = "quote" };
            const p1 = try self.allocator.create(core.Pair);
            p1.* = .{ .car = next_form, .cdr = Value.nil };
            const p2 = try self.allocator.create(core.Pair);
            p2.* = .{ .car = quote_symbol, .cdr = Value{ .pair = p1 } };
            return Value{ .pair = p2 };
        }
        if (std.mem.eql(u8, token, "(")) {
            var values = std.ArrayList(Value).init(self.allocator);
            defer values.deinit();
            while (true) {
                if (self.position >= self.tokens.items.len) {
                    return ElzError.UnmatchedOpenParen;
                }
                const next_token = self.tokens.items[self.position];
                if (std.mem.eql(u8, next_token, ")")) {
                    self.position += 1;
                    var result: Value = Value.nil;
                    var j = values.items.len;
                    while (j > 0) {
                        j -= 1;
                        const p = try self.allocator.create(core.Pair);
                        p.* = .{ .car = values.items[j], .cdr = result };
                        result = Value{ .pair = p };
                    }
                    return result;
                }
                if (std.mem.eql(u8, next_token, ".")) {
                    self.position += 1;
                    if (values.items.len == 0) return ElzError.InvalidDottedPair;
                    const cdr = try self.parse_form();
                    if (self.position >= self.tokens.items.len or !std.mem.eql(u8, self.tokens.items[self.position], ")")) {
                        return ElzError.InvalidDottedPair;
                    }
                    self.position += 1;
                    var result: Value = cdr;
                    var k = values.items.len;
                    while (k > 0) {
                        k -= 1;
                        const p = try self.allocator.create(core.Pair);
                        p.* = .{ .car = values.items[k], .cdr = result };
                        result = Value{ .pair = p };
                    }
                    return result;
                }
                try values.append(try self.parse_form());
            }
        } else if (std.mem.eql(u8, token, ")")) {
            return ElzError.UnexpectedCloseParen;
        } else {
            return parse_atom(token, self.allocator);
        }
    }
};

/// Parses an atomic value from a token.
///
/// - `token`: The token to parse.
/// - `allocator`: The memory allocator to use.
/// - `return`: The parsed `Value`.
fn parse_atom(token: []const u8, allocator: std.mem.Allocator) ElzError!Value {
    if (std.mem.eql(u8, token, "#t")) return Value{ .boolean = true };
    if (std.mem.eql(u8, token, "#f")) return Value{ .boolean = false };
    if (token.len >= 2 and token[0] == '"' and token[token.len - 1] == '"') {
        var unescaped = std.ArrayList(u8).init(allocator);
        defer unescaped.deinit();
        var i: usize = 1;
        while (i < token.len - 1) {
            if (token[i] == '\\' and i + 1 < token.len - 1) {
                switch (token[i + 1]) {
                    'n' => try unescaped.append('\n'),
                    't' => try unescaped.append('\t'),
                    '\\' => try unescaped.append('\\'),
                    '"' => try unescaped.append('"'),
                    else => {
                        try unescaped.append('\\');
                        try unescaped.append(token[i + 1]);
                    },
                }
                i += 2;
            } else {
                try unescaped.append(token[i]);
                i += 1;
            }
        }
        return Value{ .string = try unescaped.toOwnedSlice() };
    }
    if (token.len > 2 and token[0] == '#' and token[1] == '\\') {
        const char_name = token[2..];
        if (std.mem.eql(u8, char_name, "space")) return Value{ .character = ' ' };
        if (std.mem.eql(u8, char_name, "newline")) return Value{ .character = '\n' };
        if (char_name.len == 1) return Value{ .character = char_name[0] };
        return ElzError.InvalidCharacterLiteral;
    }
    const num = std.fmt.parseFloat(f64, token) catch {
        return Value{ .symbol = try allocator.dupe(u8, token) };
    };
    return Value{ .number = num };
}

/// Reads and parses a single form from a string of source code.
///
/// - `source`: The source code to parse.
/// - `allocator`: The memory allocator to use.
/// - `return`: The parsed `Value`.
pub fn read(source: []const u8, allocator: std.mem.Allocator) ElzError!Value {
    var tokens = tokenize(source, allocator) catch |err| {
        return err;
    };
    defer tokens.deinit();
    if (tokens.items.len == 0) return ElzError.EmptyInput;
    var parser = Parser{
        .tokens = tokens,
        .position = 0,
        .allocator = allocator,
    };
    return parser.parse_form();
}

/// Reads and parses all forms from a string of source code.
///
/// - `source`: The source code to parse.
/// - `allocator`: The memory allocator to use.
/// - `return`: An `ArrayList` of parsed `Value`s.
pub fn readAll(source: []const u8, allocator: std.mem.Allocator) !std.ArrayList(Value) {
    var tokens = tokenize(source, allocator) catch |err| {
        return err;
    };
    defer tokens.deinit();
    if (tokens.items.len == 0) return std.ArrayList(Value).init(allocator);

    var parser = Parser{
        .tokens = tokens,
        .position = 0,
        .allocator = allocator,
    };

    var forms = std.ArrayList(Value).init(allocator);
    while (parser.position < parser.tokens.items.len) {
        try forms.append(try parser.parse_form());
    }
    return forms;
}

test "parser" {
    const allocator = std.testing.allocator;
    const testing = std.testing;

    // Test parsing a number
    var value = try read("42", allocator);
    try testing.expect(value == Value{ .number = 42 });

    // Test parsing a symbol
    value = try read("foo", allocator);
    try testing.expect(value.is_symbol("foo"));

    // Test parsing a string
    value = try read("\"hello world\"", allocator);
    try testing.expect(value == Value{ .string = "hello world" });

    // Test parsing a list
    value = try read("(+ 1 2)", allocator);
    if (value != .pair) {
        testing.log.err("Expected a pair, got {any}", .{value});
        return error.TestExpectedPair;
    }
    var p = value.pair;
    try testing.expect(p.car.is_symbol("+"));
    p = p.cdr.pair;
    try testing.expect(p.car == Value{ .number = 1 });
    p = p.cdr.pair;
    try testing.expect(p.car == Value{ .number = 2 });
    try testing.expect(p.cdr == .nil);

    // Test parsing a quoted expression
    value = try read("'(1 2)", allocator);
    if (value != .pair) {
        testing.log.err("Expected a pair, got {any}", .{value});
        return error.TestExpectedPair;
    }
    p = value.pair;
    try testing.expect(p.car.is_symbol("quote"));
    p = p.cdr.pair;
    const inner_list = p.car;
    if (inner_list != .pair) {
        testing.log.err("Expected a pair, got {any}", .{inner_list});
        return error.TestExpectedPair;
    }
    p = inner_list.pair;
    try testing.expect(p.car == Value{ .number = 1 });
    p = p.cdr.pair;
    try testing.expect(p.car == Value{ .number = 2 });
    try testing.expect(p.cdr == .nil);

    // Test unterminated string error
    var err = read("\"hello", allocator);
    try testing.expectError(ElzError.UnterminatedString, err);

    // Test unmatched open paren error
    err = read("(", allocator);
    try testing.expectError(ElzError.UnmatchedOpenParen, err);

    // Test unexpected close paren error
    err = read(")", allocator);
    try testing.expectError(ElzError.UnexpectedCloseParen, err);
}
