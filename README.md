<div align="center">
  <picture>
    <img alt="Element 0 Logo" src="logo.svg" height="35%" width="35%">
  </picture>
<br>

<h2>Element 0</h2>

[![Tests](https://img.shields.io/github/actions/workflow/status/habedi/element-0/tests.yml?label=tests&style=flat&labelColor=282c34&logo=github)](https://github.com/habedi/element-0/actions/workflows/tests.yml)
[![Zig Version](https://img.shields.io/badge/Zig-0.14.1-orange?logo=zig&labelColor=282c34)](https://ziglang.org/download/)
[![Release](https://img.shields.io/github/release/habedi/element-0.svg?label=release&style=flat&labelColor=282c34&logo=github)](https://github.com/habedi/element-0/releases/latest)
[![Docs](https://img.shields.io/badge/docs-view-blue?style=flat&labelColor=282c34&logo=read-the-docs)](https://habedi.github.io/element-0/)
[![License](https://img.shields.io/badge/license-Apache--2.0-007ec6?label=license&style=flat&labelColor=282c34&logo=open-source-initiative)](https://github.com/habedi/element-0/blob/main/LICENSE)
[![Examples](https://img.shields.io/badge/examples-view-green?style=flat&labelColor=282c34&logo=zig)](https://github.com/habedi/element-0/tree/main/examples)

A small embeddable Lisp for the Zig ecosystem λ

</div>

---

Element 0 is a Lisp dialect implemented in the Zig programming language.
It is inspired by Scheme and aims to be compliant with
the [R5RS](https://www-sop.inria.fr/indes/fp/Bigloo/doc/r5rs-7.html) standard to a good degree, but not limited to it.

This project provides a lightweight, embeddable interpreter (named `Elz`) for Element 0.
Elz can be easily integrated into Zig applications as a scripting engine, as well as a standalone interactive
read-eval-print-loop (REPL).
Additionally, it comes with a foreign function interface (FFI) API that lets you call Zig procedures from Element 0 and
vice versa.

### Features

* A good level of R5RS compliance with a sizable standard library (see [std.elz](src/stdlib/std.elz)).
* Easy to integrate into Zig projects as a lightweight and fast scripting engine.
* Easy to extend with Zig functions via FFI.
* Comes with REPL for scripting and development.

See the [ROADMAP.md](ROADMAP.md) for the list of implemented and planned features.

> [!IMPORTANT]
> Element 0 is in early development, so bugs and breaking changes are expected.
> Please use the [issues page](https://github.com/habedi/element-0/issues) to report bugs or request features.

---

### Getting Started

Element 0 is implemented in Zig 0.14.1 and needs at least Zig 0.14.1 to build.

1. Clone the repository:
   ```sh
   git clone https://github.com/habedi/element-0.git
   cd element-0
   ```
2. Build and run the REPL:
   ```sh
   zig build repl
   ```

-----

### Documentation

You can find the full API documentation for the latest release of Element 0 [here](https://habedi.github.io/element-0/).

Alternatively, you can use the `make docs` command to generate the API documentation for the current version of
Element 0 from the source code.
This will generate HTML documentation in the `docs/api` directory, which you can serve locally with `make serve-docs`
and view in your web browser at [http://localhost:8000](http://localhost:8000).

### Examples

Check out the [examples](examples/) directory for various usage examples,
including both Element 0 code and Zig FFI examples.

---

### Contributing

Contributions are always welcome!
Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to make a contribution.

### License

Element 0 is licensed under the Apache License, Version 2.0 (see [LICENSE](LICENSE)).

### Acknowledgements

* The logo is made by [Conrad Barski, M.D.](https://www.lisperati.com/logo.html) with a few changes.
* This project uses [linenoise](https://github.com/antirez/linenoise) and [bdwgc](https://github.com/bdwgc/bdwgc) C
  libraries.
* This project uses the [Chilli](https://github.com/habedi/chilli) CLI framework.
