## Examples

This directory contains examples of how to use Element 0.

### Element 0 Examples

The `elz/` directory contains examples of Element 0 code (`.elz` files).
You can run them using the `elz` interpreter.

For example, to run the factorial example:

```sh
zig build run -- -f examples/elz/e4-factorial.elz
```

### Zig FFI Examples

The `zig/` directory contains examples of how to use the FFI to call Zig functions from Element 0 code.

For example, to run the FFI power example:

```sh
zig build run -- -f examples/zig/e1_ffi_pow.zig
```
