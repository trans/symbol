# SYMBOL WASM - Library only (no CLI/REPL)
#
# Lightweight entry point for browser/WASM builds.
# Exports C-compatible functions for JavaScript interop.

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

  # Format result for output
  def self.format_result(result : Tacit::EvalResult) : String
    case result
    when Tacit::Resolved
      value = result.value
      case value
      when Float64
        if value == value.to_i64.to_f64
          value.to_i64.to_s
        else
          value.to_s
        end
      when Array
        "[" + value.map(&.to_s).join(", ") + "]"
      else
        value.to_s
      end
    else
      result.to_s
    end
  end
end

# =============================================================================
# WASM Exports - C-compatible functions for JavaScript interop
# =============================================================================

# Keep allocated strings alive to prevent GC
SYMBOL_ALLOCATIONS = [] of Pointer(UInt8)

# Allocate memory for string input/output
fun symbol_alloc(size : Int32) : Pointer(UInt8)
  ptr = Pointer(UInt8).malloc(size)
  SYMBOL_ALLOCATIONS << ptr
  ptr
end

# Free previously allocated memory
fun symbol_free(ptr : Pointer(UInt8)) : Nil
  SYMBOL_ALLOCATIONS.delete(ptr)
end

# Evaluate an expression (takes null-terminated string, returns null-terminated string)
fun symbol_eval(input_ptr : Pointer(UInt8)) : Pointer(UInt8)
  # Read input string
  input = String.new(input_ptr)

  # Evaluate expression
  result = begin
    r = SYMBOL.eval(input)
    SYMBOL.format_result(r)
  rescue ex
    "Error: #{ex.message}"
  end

  # Allocate and return result string
  output_ptr = symbol_alloc(result.bytesize + 1)
  result.to_slice.copy_to(output_ptr, result.bytesize)
  output_ptr[result.bytesize] = 0_u8
  output_ptr
end
