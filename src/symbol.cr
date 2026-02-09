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

# CLI entry point
if ARGV.size > 0
  case ARGV[0]
  when "repl", "r"
    SYMBOL::REPL.new.run

  when "eval", "e"
    if ARGV.size < 2
      STDERR.puts "Usage: symbol eval <expression>"
      exit 1
    end
    expr = ARGV[1..].join(" ")
    result = SYMBOL.eval(expr)
    case result
    when SYMBOL::Tacit::Resolved
      value = result.value
      case value
      when Float64
        if value == value.to_i64.to_f64
          puts value.to_i64
        else
          puts value
        end
      when Array
        puts "[" + value.map(&.to_s).join(", ") + "]"
      else
        puts value
      end
    else
      puts result
    end

  when "tokenize", "t"
    if ARGV.size < 2
      STDERR.puts "Usage: symbol tokenize <expression>"
      exit 1
    end
    expr = ARGV[1..].join(" ")
    tokens = SYMBOL.tokenize(expr)
    tokens.each { |t| puts t }

  when "parse", "p"
    if ARGV.size < 2
      STDERR.puts "Usage: symbol parse <expression>"
      exit 1
    end
    expr = ARGV[1..].join(" ")
    ast = SYMBOL.parse(expr)
    pp ast

  when "version", "-v", "--version"
    puts "SYMBOL #{SYMBOL::VERSION}"

  when "help", "-h", "--help"
    puts <<-HELP
    SYMBOL #{SYMBOL::VERSION}
    An APL-inspired tacit logical programming language.

    Usage: symbol <command> [arguments]

    Commands:
      repl, r              Start interactive REPL
      eval, e <expr>       Evaluate an expression
      parse, p <expr>      Parse and show AST
      tokenize, t <expr>   Tokenize and show tokens
      version, -v          Show version
      help, -h             Show this help

    Examples:
      symbol repl
      symbol eval "2 + 3"
      symbol eval "Σ [1, 2, 3, 4]"
    HELP

  else
    STDERR.puts "Unknown command: #{ARGV[0]}"
    STDERR.puts "Run 'symbol help' for usage"
    exit 1
  end
else
  # No args - start REPL
  SYMBOL::REPL.new.run
end
