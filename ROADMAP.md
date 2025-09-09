## Feature Roadmap

This document includes the roadmap for the Element 0 programming language.
It outlines the features to be implemented and their current status.

> [!IMPORTANT]
> This roadmap is a work in progress and is subject to change without notice.

### 1. Host API and FFI

* **Embedding API**:
    * [x] An `Interpreter` struct that manages all state.
    * [x] `init` and `deinit` functions for lifecycle management.
    * [x] `evalString` to execute Element 0 code from Zig.
    * [x] `setGlobal` to define Element 0 variables from Zig values.
* **FFI**:
    * [x] Support for variadic functions. Zig functions can accept a variable number of Element 0 arguments.
    * [x] Graceful error propagation from Zig functions to the Element 0 environment.
    * [x] Support for opaque pointers. Element 0 can hold references to Zig data structures.

### 2. R5RS Compliance

#### 2.1. Core Data Types and Representation

* [x] Booleans (`#t`, `#f`)
* [x] Numbers (floating-point)
* [x] Symbols
* [x] Pairs and Lists
* [x] Characters
* [x] Strings
* [x] Procedures (closures)
* [ ] Vectors
* [ ] Hash Maps
* [ ] Ports

#### 2.2. Evaluation Semantics and Special Forms

* [x] Self-evaluating expressions
* [x] `quote`
* [x] `if`
* [x] `define`
* [x] `set!`
* [x] `lambda`
* [x] `begin`
* [x] `let`, `let*`, `letrec`
* [x] `cond`, `[ ] case`, `[x] and`, `[x] or`

#### 2.3. Standard Library Procedures

* **Equivalence Predicates**:
    * [x] `eq?`, `eqv?`, `equal?`
* **Type Predicates**:
    * [x] `null?`, `boolean?`, `symbol?`, `number?`, `list?`
* **Pair and List Manipulation**:
    * [x] `cons`, `car`, `cdr`
    * [x] `list`, `length`, `append`, `reverse`, `map`
    * [x] `for-each`
* **Numeric Operations**:
    * [x] `+`, `-`, `*`, `/`
    * [x] `=`, `<`, `>`, `<=`, `>=`
    * [x] `abs`
    * [ ] `sqrt`
    * [x] `max`
    * [x] `min`
* **Symbol Handling**:
    * [ ] `symbol->string`, `string->symbol`
* **String and Character Manipulation**:
    * [ ] `string-length`, `string-ref`, `char=?`
* **Vector Manipulation**:
    * [ ] `vector`, `make-vector`, `vector-ref`, `vector-set!`

#### 2.4. Syntactic Extensions

* [ ] `quasiquote` (` ` `), `unquote` (`,`), `unquote-splicing` (`,@`)

#### 2.5. Advanced Control Flow

* [x] `apply`
* [ ] `eval`

#### 2.6. I/O System

* [ ] `read`
* [x] `write`
* [x] `display`
* [x] `load`
* [ ] `open-input-file`, `close-input-port`

### 3. Expanded Standard Library

* [ ] **Math Library**: More common mathematical functions (e.g., trigonometric, logarithmic).
* [x] **List Utilities**: `filter`, `foldl`, `foldr`, and other common list processing functions.
* [ ] **String Utilities**: `substring`, `string-append`, `string-split`, etc.
* [ ] **Regular Expressions**: A library for advanced text pattern matching.
* [ ] **OS & Filesystem**: Procedures for file I/O, directory manipulation, and environment variables.
* [ ] **Advanced I/O**: A `format` procedure and a more comprehensive port system.
* [ ] **Date & Time**: Utilities for working with dates and times.

### 4. Advanced Language Features (Post-R5RS)

* [ ] **Hygienic Macros**: A `syntax-rules` or similar system for powerful and safe compile-time metaprogramming.
* [ ] **Module System**: A system for organizing code into reusable and encapsulated modules.
* [ ] **Error Handling**: A robust mechanism for handling runtime errors, such as `try/catch` or `with-handler`.
* [ ] `call-with-current-continuation` (`call/cc`): Support for first-class continuations.

### 5. Better Host Integration & Embeddability

* [ ] **Advanced FFI**:
    * [ ] Support for passing complex Zig structs.
    * [ ] Ability to pass Elz closures to Zig as callbacks.
    * [ ] Automatic type conversions for more data types.
* [ ] **Sandboxing & Security**:
    * [ ] A sandboxed mode to restrict access to I/O and other sensitive operations.
    * [ ] Host-level controls for memory and execution time limits.
* [ ] **Serialization**:
    * [ ] Built-in procedures to serialize and deserialize Elz objects (e.g., to JSON or S-expressions).
