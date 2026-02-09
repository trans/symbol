require "./term"
require "../ast"

# Use Symbol's AST (not Axiom's)
private alias AST = SYMBOL::AST

module SYMBOL
  module Tacit
    # Bindings from variable names to values
    alias Bindings = Hash(String, TacitValue)

    # Evaluator for tacit (RRPN) expressions
    # Evaluates right-to-left, building suspended computations
    class Evaluator
      # Evaluate an expression given variable bindings
      def eval(expr : AST::Expression, bindings : Bindings) : EvalResult
        eval_terms(expr.terms, bindings)
      end

      # Evaluate a list of terms right-to-left
      def eval_terms(terms : Array(AST::ExprTerm), bindings : Bindings) : EvalResult
        return Resolved.new(nil) if terms.empty?

        # Process right-to-left
        result : EvalResult = Resolved.new(nil)

        terms.reverse_each do |term|
          result = apply_term(term, result, bindings)
        end

        result
      end

      # Apply a single term to the current result
      private def apply_term(term : AST::ExprTerm, current : EvalResult, bindings : Bindings) : EvalResult
        case term
        when AST::ExprLiteral
          apply_value(term.value, current)
        when AST::ExprList
          # Evaluate list items and build array
          arr = eval_list(term, bindings)
          apply_value(arr, current)
        when AST::ExprGrouped
          # Evaluate grouped expression as a unit
          result = eval_terms(term.terms, bindings)
          case result
          when Resolved
            apply_value(result.value, current)
          else
            result
          end
        when AST::ExprVariable
          if bindings.has_key?(term.name)
            apply_value(bindings[term.name], current)
          else
            apply_unbound(term.name, current)
          end
        when AST::ExprOperator
          apply_operator(term.symbol, term.arity, current)
        else
          current
        end
      end

      # Apply a literal or bound value
      private def apply_value(value : TacitValue, current : EvalResult) : EvalResult
        case current
        when Resolved
          # First value - just return it
          if current.value.nil?
            Resolved.new(value)
          else
            # Two values with no operator - error or implicit operation?
            # For now, return the new value
            Resolved.new(value)
          end
        when Suspended
          # Add as argument to suspended operation
          new_args = [Resolved.new(value).as(EvalResult)] + current.args
          new_suspended = Suspended.new(current.op, current.arity, new_args)
          if new_suspended.complete?
            execute(new_suspended)
          else
            new_suspended
          end
        when Unbound
          # Can't do much with unbound variable
          current
        else
          Resolved.new(value)
        end
      end

      # Apply an unbound variable reference
      private def apply_unbound(name : String, current : EvalResult) : EvalResult
        case current
        when Suspended
          # Add unbound as argument
          new_args = [Unbound.new(name).as(EvalResult)] + current.args
          Suspended.new(current.op, current.arity, new_args)
        else
          Unbound.new(name)
        end
      end

      # Apply an operator - creates a suspended computation
      private def apply_operator(symbol : String, arity : Int32, current : EvalResult) : EvalResult
        case current
        when Resolved
          if current.value.nil?
            # No right argument yet - fully suspended
            Suspended.new(symbol, arity)
          else
            # Right argument exists - partially applied
            args = [current.as(EvalResult)]
            suspended = Suspended.new(symbol, arity, args)
            if suspended.complete?
              execute(suspended)
            else
              suspended
            end
          end
        when Suspended
          # Chain operators - current becomes the right arg
          args = [current.as(EvalResult)]
          Suspended.new(symbol, arity, args)
        when Unbound
          # Operator with unbound variable
          args = [current.as(EvalResult)]
          Suspended.new(symbol, arity, args)
        else
          Suspended.new(symbol, arity)
        end
      end

      # Execute a complete suspended computation
      private def execute(suspended : Suspended) : EvalResult
        # First, resolve all arguments
        args = suspended.args.map { |arg| resolve_arg(arg) }

        # Check for any unresolved arguments
        if args.any?(&.nil?)
          return suspended # Can't execute yet
        end

        values = args.map(&.not_nil!)

        case suspended.op
        # Arithmetic (with vectorization)
        when "+"
          vectorize_binary(values[0], values[1]) { |a, b| a + b }
        when "-"
          vectorize_binary(values[0], values[1]) { |a, b| a - b }
        when "*"
          vectorize_binary(values[0], values[1]) { |a, b| a * b }
        when "/"
          vectorize_binary(values[0], values[1]) { |a, b| b == 0 ? Float64::INFINITY : a / b }
        when "%"
          vectorize_binary(values[0], values[1]) { |a, b| a % b }
        when "^"
          vectorize_binary(values[0], values[1]) { |a, b| a ** b }

        # Range
        when ".."
          start_val = to_num(values[0]).to_i64
          end_val = to_num(values[1]).to_i64
          if start_val <= end_val
            result = (start_val..end_val).map { |n| n.to_f64.as(TacitValue) }
          else
            result = (end_val..start_val).reverse_each.map { |n| n.to_f64.as(TacitValue) }.to_a
          end
          Resolved.new(result.as(TacitValue))

        # Comparison
        when "=", "=="
          Resolved.new(values[0] == values[1])
        when "!=", "≠"
          Resolved.new(values[0] != values[1])
        when "<"
          Resolved.new(to_num(values[0]) < to_num(values[1]))
        when ">"
          Resolved.new(to_num(values[0]) > to_num(values[1]))
        when "<=", "≤"
          Resolved.new(to_num(values[0]) <= to_num(values[1]))
        when ">=", "≥"
          Resolved.new(to_num(values[0]) >= to_num(values[1]))

        # Logic
        when "!"
          Resolved.new(!to_bool(values[0]))

        # Negation
        when "~"
          case values[0]
          when Float64
            Resolved.new(-values[0].as(Float64))
          when Array
            arr = values[0].as(Array(TacitValue))
            Resolved.new(arr.map { |v| (-to_num(v)).as(TacitValue) }.as(TacitValue))
          else
            Resolved.new(-to_num(values[0]))
          end

        # Bitwise/Boolean operators (wrapped) - dispatch by type
        when "[+]"
          # Bool, Bool → boolean OR; else bitwise OR
          if values[0].is_a?(Bool) && values[1].is_a?(Bool)
            Resolved.new(values[0].as(Bool) || values[1].as(Bool))
          else
            vectorize_binary(values[0], values[1]) { |a, b| (a.to_i64 | b.to_i64).to_f64 }
          end
        when "[*]"
          # Bool, Bool → boolean AND; else bitwise AND
          if values[0].is_a?(Bool) && values[1].is_a?(Bool)
            Resolved.new(values[0].as(Bool) && values[1].as(Bool))
          else
            vectorize_binary(values[0], values[1]) { |a, b| (a.to_i64 & b.to_i64).to_f64 }
          end
        when "[-]"
          # Bool, Bool → boolean XOR; else bitwise XOR
          if values[0].is_a?(Bool) && values[1].is_a?(Bool)
            Resolved.new(values[0].as(Bool) != values[1].as(Bool))
          else
            vectorize_binary(values[0], values[1]) { |a, b| (a.to_i64 ^ b.to_i64).to_f64 }
          end
        when "[~]"
          # Bool → boolean NOT; else bitwise NOT
          case values[0]
          when Bool
            Resolved.new(!values[0].as(Bool))
          when Float64
            Resolved.new((~values[0].as(Float64).to_i64).to_f64)
          when Array
            arr = values[0].as(Array(TacitValue))
            Resolved.new(arr.map { |v|
              if v.is_a?(Bool)
                (!v.as(Bool)).as(TacitValue)
              else
                (~to_num(v).to_i64).to_f64.as(TacitValue)
              end
            }.as(TacitValue))
          else
            Resolved.new((~to_num(values[0]).to_i64).to_f64)
          end

        # Aggregation (unary - operate on arrays)
        when "Σ", "sum"
          arr = to_array(values[0])
          Resolved.new(arr.sum { |v| to_num(v) })
        when "Π", "prod"
          arr = to_array(values[0])
          Resolved.new(arr.product { |v| to_num(v) })
        when "#", "count"
          arr = to_array(values[0])
          Resolved.new(arr.size.to_f64)
        when "⌈", "max"
          arr = to_array(values[0])
          Resolved.new(arr.max_of { |v| to_num(v) })
        when "⌊", "min"
          arr = to_array(values[0])
          Resolved.new(arr.min_of { |v| to_num(v) })

        # Structural operators
        when "><"  # concat
          arr1 = to_array(values[0])
          arr2 = to_array(values[1])
          Resolved.new((arr1 + arr2).as(TacitValue))

        when "<>"  # wrap
          result = [values[0].as(TacitValue), values[1].as(TacitValue)]
          Resolved.new(result.as(TacitValue))

        when "+>"  # cons (prepend element)
          arr = to_array(values[1])
          result = [values[0].as(TacitValue)] + arr
          Resolved.new(result.as(TacitValue))

        when "<+"  # snoc (append element)
          arr = to_array(values[0])
          result = arr + [values[1].as(TacitValue)]
          Resolved.new(result.as(TacitValue))

        when "~>"  # zip
          arr1 = to_array(values[0])
          arr2 = to_array(values[1])
          result = [] of TacitValue
          max_len = {arr1.size, arr2.size}.max
          max_len.times do |i|
            result << arr1[i]? if i < arr1.size
            result << arr2[i]? if i < arr2.size
          end
          Resolved.new(result.as(TacitValue))

        when "<~"  # piz (reverse zip)
          arr1 = to_array(values[0])
          arr2 = to_array(values[1])
          result = [] of TacitValue
          max_len = {arr1.size, arr2.size}.max
          max_len.times do |i|
            result << arr2[i]? if i < arr2.size
            result << arr1[i]? if i < arr1.size
          end
          Resolved.new(result.as(TacitValue))

        when "->"  # remove from back (must match end)
          arr = to_array(values[0])
          suffix = to_array(values[1])
          # Check if arr ends with suffix
          if arr.size >= suffix.size
            match = true
            suffix.size.times do |i|
              if arr[arr.size - suffix.size + i] != suffix[i]
                match = false
                break
              end
            end
            if match
              result = arr[0, arr.size - suffix.size]
              Resolved.new(result.as(TacitValue))
            else
              Resolved.new(arr.as(TacitValue))
            end
          else
            Resolved.new(arr.as(TacitValue))
          end

        when "<-"  # remove from front (must match start)
          arr = to_array(values[0])
          prefix = to_array(values[1])
          # Check if arr starts with prefix
          if arr.size >= prefix.size
            match = true
            prefix.size.times do |i|
              if arr[i] != prefix[i]
                match = false
                break
              end
            end
            if match
              result = arr[prefix.size..]
              Resolved.new(result.as(TacitValue))
            else
              Resolved.new(arr.as(TacitValue))
            end
          else
            Resolved.new(arr.as(TacitValue))
          end

        when "<->"  # remove from both ends
          arr = to_array(values[0])
          fix = to_array(values[1])
          result = arr.dup
          # Remove from front if matches
          if result.size >= fix.size
            match = true
            fix.size.times do |i|
              if result[i] != fix[i]
                match = false
                break
              end
            end
            result = result[fix.size..] if match
          end
          # Remove from back if matches
          if result.size >= fix.size
            match = true
            fix.size.times do |i|
              if result[result.size - fix.size + i] != fix[i]
                match = false
                break
              end
            end
            result = result[0, result.size - fix.size] if match
          end
          Resolved.new(result.as(TacitValue))

        when "↑"  # take (1-indexed, negative from end)
          n = to_num(values[0]).to_i32
          arr = to_array(values[1])
          if n >= 0
            result = arr[0, {n, arr.size}.min]?
          else
            result = arr[{arr.size + n, 0}.max..]?
          end
          Resolved.new((result || [] of TacitValue).as(TacitValue))

        when "↓"  # drop (1-indexed, negative from end)
          n = to_num(values[0]).to_i32
          arr = to_array(values[1])
          if n >= 0
            result = arr[{n, arr.size}.min..]?
          else
            result = arr[0, {arr.size + n, 0}.max]?
          end
          Resolved.new((result || [] of TacitValue).as(TacitValue))

        when "@"  # index (1-indexed, negative from end)
          n = to_num(values[0]).to_i32
          arr = to_array(values[1])
          if n > 0
            Resolved.new(arr[n - 1]?)
          elsif n < 0
            Resolved.new(arr[arr.size + n]?)
          else
            Resolved.new(nil)
          end

        when "⌽"  # reverse
          arr = to_array(values[0])
          Resolved.new(arr.reverse.as(TacitValue))

        else
          # Unknown operator - return suspended
          suspended
        end
      end

      private def resolve_arg(arg : EvalResult) : TacitValue?
        case arg
        when Resolved
          arg.value
        when Suspended
          result = execute(arg)
          if result.is_a?(Resolved)
            result.value
          else
            nil
          end
        else
          nil
        end
      end

      # Vectorize a binary operation over arrays
      private def vectorize_binary(left : TacitValue, right : TacitValue, &block : (Float64, Float64) -> Float64) : EvalResult
        case {left, right}
        when {Array, Array}
          # Element-wise operation
          larr = left.as(Array(TacitValue))
          rarr = right.as(Array(TacitValue))
          # Zip with shorter length, or could pad - for now, zip
          result = larr.zip(rarr).map { |(l, r)| block.call(to_num(l), to_num(r)).as(TacitValue) }
          Resolved.new(result.as(TacitValue))
        when {Array, _}
          # Map scalar over array
          arr = left.as(Array(TacitValue))
          scalar = to_num(right)
          result = arr.map { |v| block.call(to_num(v), scalar).as(TacitValue) }
          Resolved.new(result.as(TacitValue))
        when {_, Array}
          # Map scalar over array
          scalar = to_num(left)
          arr = right.as(Array(TacitValue))
          result = arr.map { |v| block.call(scalar, to_num(v)).as(TacitValue) }
          Resolved.new(result.as(TacitValue))
        else
          # Scalar operation
          Resolved.new(block.call(to_num(left), to_num(right)))
        end
      end

      private def to_num(v : TacitValue) : Float64
        case v
        when Float64 then v
        when String  then v.to_f64? || 0.0
        when Bool    then v ? 1.0 : 0.0
        when Array   then v.size.to_f64
        else              0.0
        end
      end

      private def to_bool(v : TacitValue) : Bool
        case v
        when Float64 then v != 0.0
        when String  then !v.empty?
        when Bool    then v
        when Array   then !v.empty?
        else              false
        end
      end

      private def to_array(v : TacitValue) : Array(TacitValue)
        case v
        when Array(TacitValue) then v
        when String            then v.chars.map { |c| c.to_s.as(TacitValue) }
        when Nil               then [] of TacitValue
        else
          result = [] of TacitValue
          result << v
          result
        end
      end

      # Evaluate a list expression to an array
      private def eval_list(list : AST::ExprList, bindings : Bindings) : Array(TacitValue)
        result = [] of TacitValue
        list.items.each do |item|
          case item
          when AST::ExprLiteral
            result << item.value.as(TacitValue)
          when AST::ExprVariable
            result << (bindings[item.name]? || nil)
          when AST::ExprList
            result << eval_list(item, bindings).as(TacitValue)
          else
            result << nil
          end
        end
        result
      end
    end
  end
end
