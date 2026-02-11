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
