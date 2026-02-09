# SYMBOL WASM - Library only (no CLI/REPL)
#
# Lightweight entry point for browser/WASM builds.

require "./symbol/ast"
require "./symbol/lexer"
require "./symbol/parser"
require "./symbol/tacit/term"
require "./symbol/tacit/eval"

module SYMBOL
  VERSION = "0.1.0"

  # Evaluate an expression string
  def self.eval(source : String, bindings = {} of String => Tacit::TacitValue) : Tacit::EvalResult
    expr = Parser.parse(source)
    Tacit::Evaluator.new.eval(expr, bindings)
  end

  # Parse an expression string
  def self.parse(source : String) : AST::Expression
    Parser.parse(source)
  end

  # Tokenize an expression string
  def self.tokenize(source : String) : Array(Token)
    Lexer.new(source).tokenize
  end
end
