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
    * [ ] `for-each`
* **Numeric Operations**:
    * [x] `+`, `-`, `*`, `/`
    * [x] `=`, `<`, `>`, `<=`, `>=`
    * [ ] `abs`, `sqrt`, `max`, `min`
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
* [ ] `call-with-current-continuation` (`call/cc`)
* [ ] `eval`

#### 2.6. I/O System

* [ ] `read`, `write`, `display`
* [ ] `load`
* [ ] `open-input-file`, `close-input-port`

### 3. Additional Features

#### 3.1. Standard Library

* [ ] Math library with common mathematical functions.
* [ ] List processing utilities like `filter`, `foldl`, `foldr`.
* [ ] String manipulation functions like `substring`, `string-append`.
* [ ] Date and time utilities.
* [ ] File system operations.
