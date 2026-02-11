# SYMBOL - Set-Yielding Model of Bound Operations and Logic
#
# An APL-inspired tacit logical programming language.
# Provides expression evaluation and logic unification.

require "./symbol/ast"
require "./symbol/lexer"
require "./symbol/parser"
require "./symbol/tacit/term"
require "./symbol/tacit/eval"
require "./symbol/repl"
require "./symbol/inline"
require "./symbol/statement"

module SYMBOL
  VERSION = "0.2.0"

  # Evaluate a SYMBOL expression or multi-statement program.
  #
  # - `program: false` (default) — single expression, `=` and `.` are errors
  # - `program: true` — statements separated by `.`, `=` is assignment
  #
  # Bindings are mutated in place when `program: true`.
  def self.eval(source : String, bindings = {} of String => Tacit::TacitValue, *, program : Bool = false) : Tacit::EvalResult
    if program
      StatementParser.eval_program(source, bindings)
    else
      expr = Parser.parse(source)
      Tacit::Evaluator.new.eval(expr, bindings)
    end
  end

  # Parse an expression string
  def self.parse(source : String) : AST::Expression
    Parser.parse(source)
  end

  # Tokenize an expression string
  def self.tokenize(source : String) : Array(Token)
    Lexer.new(source).tokenize
  end

  # Process inline `{{ expr }}` expressions in text.
  #
  # Evaluates SYMBOL expressions embedded in `{{ }}` delimiters,
  # respecting markdown code spans/fences and backslash escaping.
  def self.inline(text : String, bindings = {} of String => Tacit::TacitValue) : String
    Inline.process(text, bindings)
  end
end
