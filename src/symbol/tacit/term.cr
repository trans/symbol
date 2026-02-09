module SYMBOL
  module Tacit
    # Runtime value types
    alias TacitValue = Float64 | String | Bool | Array(TacitValue) | Nil

    # Result of evaluation - either a concrete value or a suspended computation
    abstract class EvalResult
    end

    # A concrete resolved value
    class Resolved < EvalResult
      property value : TacitValue

      def initialize(@value)
      end

      def to_s(io : IO) : Nil
        io << "Resolved(" << value << ")"
      end
    end

    # A suspended computation waiting for more arguments
    class Suspended < EvalResult
      property op : String
      property arity : Int32
      property args : Array(EvalResult)

      def initialize(@op : String, @arity : Int32, args : Array(EvalResult) = [] of EvalResult)
        @args = args
      end

      def needs_args : Int32
        arity - args.size
      end

      def complete? : Bool
        args.size >= arity
      end

      def to_s(io : IO) : Nil
        io << "Suspended(" << op << ", args=" << args << ")"
      end
    end

    # A variable reference waiting to be bound
    class Unbound < EvalResult
      property name : String

      def initialize(@name)
      end

      def to_s(io : IO) : Nil
        io << "Unbound(" << name << ")"
      end
    end
  end
end
