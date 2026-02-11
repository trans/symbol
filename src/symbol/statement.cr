# SYMBOL Statement Parser
#
# Handles multi-statement programs separated by `.` with `=` assignment.
# Operates on the token stream, splitting on Period tokens and dispatching
# to the expression parser for each statement.
#
# TODO: Decide whether newlines should also act as statement separators
#       (like `.`), so multi-line programs don't require explicit periods.
#
# TODO: Consider enforcing SSA (Static Single Assignment) — currently
#       variables can be reassigned freely. SSA would error on re-binding.

require "./lexer"
require "./parser"
require "./tacit/term"
require "./tacit/eval"

module SYMBOL
  class StatementParser
    # Evaluate a multi-statement program.
    #
    # Statements are separated by `.`. Assignment uses `=`.
    # Returns the result of the last statement. Bindings are mutated in place.
    #
    # ```
    # StatementParser.eval_program("x = 4. x + 2.", bindings)  # => Resolved(6)
    # ```
    def self.eval_program(source : String, bindings : Tacit::Bindings) : Tacit::EvalResult
      tokens = Lexer.new(source).tokenize
      evaluator = Tacit::Evaluator.new
      result : Tacit::EvalResult = Tacit::Resolved.new(nil)

      statements = split_statements(tokens)

      statements.each do |stmt_tokens|
        next if stmt_tokens.empty?

        if assignment?(stmt_tokens)
          name = stmt_tokens[0].value
          expr_tokens = stmt_tokens[2..].dup
          expr_tokens << Token.new(TokenType::EOF, "")
          expr = Parser.new(expr_tokens).parse
          result = evaluator.eval(expr, bindings)
          if result.is_a?(Tacit::Resolved)
            bindings[name] = result.value
          end
        else
          expr_tokens = stmt_tokens.dup
          expr_tokens << Token.new(TokenType::EOF, "")
          expr = Parser.new(expr_tokens).parse
          result = evaluator.eval(expr, bindings)
        end
      end

      result
    end

    private def self.split_statements(tokens : Array(Token)) : Array(Array(Token))
      statements = [] of Array(Token)
      current = [] of Token

      tokens.each do |tok|
        case tok.type
        when TokenType::Period
          statements << current unless current.empty?
          current = [] of Token
        when TokenType::EOF
          # skip
        else
          current << tok
        end
      end

      statements << current unless current.empty?
      statements
    end

    private def self.assignment?(tokens : Array(Token)) : Bool
      tokens.size >= 3 &&
        tokens[0].type == TokenType::Identifier &&
        tokens[1].type == TokenType::Assign
    end
  end
end
