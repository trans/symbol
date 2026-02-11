# SYMBOL REPL

require "./lexer"
require "./parser"
require "./tacit/term"
require "./tacit/eval"

module SYMBOL
  class REPL
    @bindings : Tacit::Bindings
    @evaluator : Tacit::Evaluator

    def initialize
      @bindings = {} of String => Tacit::TacitValue
      @evaluator = Tacit::Evaluator.new
    end

    def run
      puts "SYMBOL v#{VERSION}"
      puts "Type expressions to evaluate. Type 'quit' or Ctrl+D to exit."
      puts

      loop do
        print "> "
        STDOUT.flush

        line = gets
        break if line.nil? # EOF

        input = line.strip
        next if input.empty?
        break if input == "quit" || input == "exit"

        # Handle special commands
        if input.starts_with?("let ")
          handle_let(input[4..])
          next
        end

        if input == "vars"
          show_vars
          next
        end

        if input == "clear"
          @bindings.clear
          puts "Bindings cleared."
          next
        end

        if input == "help"
          show_help
          next
        end

        # Evaluate expression
        begin
          expr = Parser.parse(input)
          result = @evaluator.eval(expr, @bindings)
          puts format_result(result)
        rescue ex : ParseError
          puts "Parse error: #{ex.message}"
        rescue ex
          puts "Error: #{ex.message}"
        end
      end

      puts "\nGoodbye!"
    end

    private def handle_let(assignment : String)
      parts = assignment.split("=", 2)
      if parts.size != 2
        puts "Usage: let name = expression"
        return
      end

      name = parts[0].strip
      expr_str = parts[1].strip

      begin
        expr = Parser.parse(expr_str)
        result = @evaluator.eval(expr, @bindings)

        if result.is_a?(Tacit::Resolved)
          @bindings[name] = result.value
          puts "#{name} = #{format_value(result.value)}"
        else
          puts "Cannot bind unresolved value"
        end
      rescue ex : ParseError
        puts "Parse error: #{ex.message}"
      rescue ex
        puts "Error: #{ex.message}"
      end
    end

    private def show_vars
      if @bindings.empty?
        puts "No bindings."
      else
        @bindings.each do |name, value|
          puts "#{name} = #{format_value(value)}"
        end
      end
    end

    private def show_help
      puts <<-HELP
      SYMBOL REPL Commands:
        let name = expr   Bind a variable
        vars              Show all bindings
        clear             Clear all bindings
        help              Show this help
        quit / exit       Exit the REPL

      Operators:
        Arithmetic:    + - * / % ^ (power)
        Comparison:    == < > <= >= != ≤ ≥ ≠
        Logic/Bitwise: [+] (or)  [*] (and)  [-] (xor)  [~] (not)  ! (not)
        Aggregation:   Σ (sum)  Π (prod)  # (count)  ⌈ (max)  ⌊ (min)
        Range:         .. (inclusive, e.g. 1..5 → [1,2,3,4,5])
        Structural:    >< (concat)  <> (wrap)  +> (cons)  <+ (snoc)
                       ~> (zip)  <~ (piz)
                       -> (remove-back)  <- (remove-front)  <-> (remove-both)
                       ↑ (take)  ↓ (drop)  @ (index)  ⌽ (reverse)

      Examples:
        > 2 + 3
        5
        > Σ [1, 2, 3, 4]
        10
        > let x = 5
        > x * x
        25
      HELP
    end

    private def format_result(result : Tacit::EvalResult) : String
      case result
      when Tacit::Resolved
        format_value(result.value)
      when Tacit::Suspended
        "⟨suspended: #{result.op} needs #{result.needs_args} more arg(s)⟩"
      when Tacit::Unbound
        "⟨unbound: #{result.name}⟩"
      else
        "⟨unknown⟩"
      end
    end

    private def format_value(value : Tacit::TacitValue) : String
      case value
      when Int64
        value.to_s
      when Float64
        value.to_s
      when String
        "\"#{value}\""
      when Bool
        value.to_s
      when Array
        "[" + value.map { |v| format_value(v) }.join(", ") + "]"
      when Nil
        "nil"
      else
        value.to_s
      end
    end
  end
end
