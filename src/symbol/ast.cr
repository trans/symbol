# SYMBOL Expression AST
#
# AST types for SYMBOL expressions. These are used by the tacit evaluator.

module SYMBOL
  module AST
    # Source location for error reporting
    struct Location
      property file : String
      property line : Int32
      property column : Int32

      def initialize(@file = "", @line = 1, @column = 1)
      end

      def to_s(io : IO) : Nil
        io << file << ":" << line << ":" << column
      end
    end

    # Expression value (tacit/RRPN): i=(k+1), n=(Σs)
    class Expression
      property terms : Array(ExprTerm)
      property location : Location?

      def initialize(@terms = [] of ExprTerm, @location = nil)
      end
    end

    # Abstract base for expression terms
    abstract class ExprTerm
      property location : Location?

      def initialize(@location = nil)
      end
    end

    # Literal in expression: numbers, strings, booleans
    class ExprLiteral < ExprTerm
      property value : Float64 | String | Bool

      def initialize(@value, location = nil)
        super(location)
      end
    end

    # List literal in expression: [1, 2, 3]
    class ExprList < ExprTerm
      property items : Array(ExprTerm)

      def initialize(@items = [] of ExprTerm, location = nil)
        super(location)
      end
    end

    # Grouped expression: (expr) - evaluates as a unit
    class ExprGrouped < ExprTerm
      property terms : Array(ExprTerm)

      def initialize(@terms = [] of ExprTerm, location = nil)
        super(location)
      end
    end

    # Variable reference in expression
    class ExprVariable < ExprTerm
      property name : String

      def initialize(@name, location = nil)
        super(location)
      end
    end

    # Operator in expression
    class ExprOperator < ExprTerm
      property symbol : String
      property arity : Int32

      # Built-in operators with their arities
      OPERATORS = {
        # Arithmetic (binary)
        "+"  => 2, "-" => 2, "*" => 2, "/" => 2, "%" => 2,
        # Comparison (binary)
        "="  => 2, "==" => 2, "!=" => 2, "≠" => 2,
        "<"  => 2, ">" => 2, "<=" => 2, ">=" => 2, "≤" => 2, "≥" => 2,
        # Logic (binary and unary)
        "&"  => 2, "|" => 2, "!" => 1,
        # Negation
        "~" => 1,
        # Bitwise (wrapped)
        "[+]" => 2, "[*]" => 2, "[-]" => 2, "[~]" => 1,
        # Aggregation (unary - operate on collections)
        "Σ"  => 1,  # sum
        "Π"  => 1,  # product
        "#"  => 1,  # count
        "⌈"  => 1,  # max/ceiling
        "⌊"  => 1,  # min/floor
        # Special
        "?" => 2, # query/unify
        "@" => 2, # apply
      }

      def initialize(@symbol, @arity = -1, location = nil)
        if @arity == -1
          @arity = OPERATORS[@symbol]? || 2
        end
        super(location)
      end

      def unary?
        arity == 1
      end

      def binary?
        arity == 2
      end
    end

    # Suspended/partial application (waiting for more args)
    class ExprSuspended < ExprTerm
      property op : ExprOperator
      property args : Array(ExprTerm)

      def initialize(@op, @args = [] of ExprTerm, location = nil)
        super(location)
      end

      def complete?
        args.size >= op.arity
      end
    end
  end
end
