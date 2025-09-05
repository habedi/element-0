//! This module defines the error set for the Element 0 interpreter.
//! These errors can occur during parsing, evaluation, or execution.

/// The set of all errors that can be returned by the Elz interpreter.
pub const ElzError = error{
    /// Indicates that the garbage collector could not allocate more memory.
    OutOfMemory,
    /// A symbol was not found in the current environment.
    SymbolNotFound,
    /// A string literal was not terminated with a double quote.
    UnterminatedString,
    /// The input ended unexpectedly, for example in the middle of a list.
    UnexpectedEndOfInput,
    /// An open parenthesis was not matched with a closing parenthesis.
    UnmatchedOpenParen,
    /// A closing parenthesis was found without a matching open parenthesis.
    UnexpectedCloseParen,
    /// An invalid character literal was found, e.g., `#\too-long`.
    InvalidCharacterLiteral,
    /// The input was empty.
    EmptyInput,
    /// The `quote` special form was called with an invalid number of arguments.
    QuoteInvalidArguments,
    /// The `if` special form was called with an invalid number of arguments.
    IfInvalidArguments,
    /// The `define` special form was called with an invalid number of arguments.
    DefineInvalidArguments,
    /// The `define` special form was called with an invalid symbol.
    DefineInvalidSymbol,
    /// The `lambda` special form was called with an invalid number of arguments.
    LambdaInvalidArguments,
    /// The parameters of a `lambda` were not valid symbols.
    LambdaInvalidParams,
    /// A procedure was called with the wrong number of arguments.
    WrongArgumentCount,
    /// A value that is not a procedure was called as if it were.
    NotAFunction,
    /// A procedure was called with an argument of the wrong type.
    InvalidArgument,
    /// A division by zero was attempted.
    DivisionByZero,
    /// An error occurred in a foreign function.
    ForeignFunctionError,
    /// The requested feature is not yet implemented.
    NotImplemented,
    /// A dotted pair was not formed correctly.
    InvalidDottedPair,
    /// The `set!` special form was called with an invalid number of arguments.
    SetInvalidArguments,
    /// The `set!` special form was called with an invalid symbol.
    SetInvalidSymbol,
    /// The execution fuel/budget has been exceeded.
    ExecutionBudgetExceeded,
};
