module SYMBOL
  # Inline expression processing for `{{ ... }}` in text.
  #
  # Scans text for `{{ expr }}` patterns and evaluates them with SYMBOL.eval.
  # Respects markdown code spans and code fences (treated as literal).
  # Backslash-escaped `\{{ ... }}` is emitted as literal `{{ ... }}`.
  #
  # ```
  # SYMBOL::Inline.process("x is {{ 2 + 3 }}")  # => "x is 5"
  # ```
  module Inline
    extend self

    # Process `{{ expr }}` expressions in text.
    #
    # - `{{ expr }}` → evaluated result
    # - Inside code spans/fences → literal (no evaluation)
    # - `\{{ expr }}` → literal `{{ expr }}`
    # - On eval failure → original `{{ expr }}` unchanged
    def process(
      text : String,
      bindings = {} of String => Tacit::TacitValue
    ) : String
      result = String::Builder.new(text.bytesize)
      i = 0
      len = text.size

      # Track code fence state
      in_code_fence = false
      fence_prefix = ""  # the backtick sequence that opened the fence

      while i < len
        ch = text[i]

        if in_code_fence
          # Look for closing fence: line starting with same backtick count
          if ch == '\n'
            result << ch
            i += 1
            # Check if next line starts with closing fence
            fence_end = scan_code_fence_close(text, i, fence_prefix)
            if fence_end > 0
              result << text[i...fence_end]
              i = fence_end
              in_code_fence = false
            end
          else
            result << ch
            i += 1
          end
          next
        end

        # Normal state

        # Code fence opening: ``` at start of line (or start of text)
        if ch == '`' && at_line_start?(text, i)
          fence_end, fence_str = scan_code_fence_open(text, i)
          if fence_end > 0
            in_code_fence = true
            fence_prefix = fence_str
            result << text[i...fence_end]
            i = fence_end
            next
          end
        end

        # Code span: `...`
        if ch == '`'
          span_end = scan_code_span(text, i)
          if span_end > 0
            result << text[i...span_end]
            i = span_end
            next
          end
        end

        # Escaped expression: \{{
        if ch == '\\' && i + 2 < len && text[i + 1] == '{' && text[i + 2] == '{'
          result << "{{"
          i += 3  # skip \{{
          next
        end

        # Expression: {{ ... }}
        if ch == '{' && i + 1 < len && text[i + 1] == '{'
          expr_start = i + 2
          expr_end = find_closing_braces(text, expr_start)
          if expr_end > 0
            expr = text[expr_start...expr_end].strip
            original = text[i..expr_end + 1]  # includes {{ and }}

            if expr.empty?
              result << original
            else
              evaluated = evaluate(expr, bindings)
              result << (evaluated || original)
            end

            i = expr_end + 2  # past }}
            next
          end
        end

        result << ch
        i += 1
      end

      result.to_s
    end

    # Format a TacitValue for inline substitution.
    def format(value : Tacit::TacitValue) : String
      case value
      when Int64
        value.to_s
      when Float64
        value.to_s
      when String
        value
      when Bool
        value.to_s
      when Array
        "[" + value.map { |v| format(v) }.join(", ") + "]"
      when Nil
        ""
      else
        value.to_s
      end
    end

    # Try to evaluate an expression. Returns formatted result or nil on failure.
    private def evaluate(expr : String, bindings) : String?
      result = SYMBOL.eval(expr, bindings, program: true)
      case result
      when Tacit::Resolved
        format(result.value)
      else
        nil  # Suspended, Unbound → leave original
      end
    rescue ex
      nil  # Parse/eval failure → leave original
    end

    # Find matching `}}` starting from pos (which is just past `{{`).
    # Returns index of first `}` in `}}`, or -1 if not found.
    private def find_closing_braces(text : String, pos : Int32) : Int32
      i = pos
      len = text.size
      while i + 1 < len
        if text[i] == '}' && text[i + 1] == '}'
          return i
        end
        i += 1
      end
      -1
    end

    # Check if position is at the start of a line (or start of text).
    private def at_line_start?(text : String, pos : Int32) : Bool
      pos == 0 || text[pos - 1] == '\n'
    end

    # Scan for a code fence opening (3+ backticks at line start).
    # Returns {end_of_line_position, backtick_prefix} or {-1, ""}.
    private def scan_code_fence_open(text : String, pos : Int32) : {Int32, String}
      i = pos
      len = text.size

      # Count backticks
      backtick_count = 0
      while i < len && text[i] == '`'
        backtick_count += 1
        i += 1
      end

      return {-1, ""} if backtick_count < 3

      fence_str = "`" * backtick_count

      # Skip to end of line (info string like "crystal" follows backticks)
      while i < len && text[i] != '\n'
        i += 1
      end

      # Include the newline if present
      i += 1 if i < len && text[i] == '\n'

      {i, fence_str}
    end

    # Scan for a code fence close. Returns end position or -1.
    private def scan_code_fence_close(text : String, pos : Int32, fence_prefix : String) : Int32
      i = pos
      len = text.size

      # Check if line starts with the same fence prefix
      fence_len = fence_prefix.size
      return -1 if i + fence_len > len

      fence_len.times do |j|
        return -1 if text[i + j] != '`'
      end

      # Must be only backticks (possibly more) then optional whitespace then newline/EOF
      i += fence_len
      while i < len && text[i] == '`'
        i += 1
      end
      while i < len && text[i] == ' '
        i += 1
      end

      if i >= len || text[i] == '\n'
        i += 1 if i < len  # include newline
        return i
      end

      -1
    end

    # Scan a code span. Returns end position (past closing backtick(s)) or -1.
    private def scan_code_span(text : String, pos : Int32) : Int32
      i = pos
      len = text.size

      # Count opening backticks
      backtick_count = 0
      while i < len && text[i] == '`'
        backtick_count += 1
        i += 1
      end

      return -1 if backtick_count == 0

      # Don't treat 3+ backticks at line start as code span (it's a fence)
      if backtick_count >= 3 && at_line_start?(text, pos)
        return -1
      end

      # Find matching closing backtick sequence (same count)
      while i < len
        if text[i] == '`'
          close_count = 0
          j = i
          while j < len && text[j] == '`'
            close_count += 1
            j += 1
          end
          if close_count == backtick_count
            return j
          end
          i = j
        else
          i += 1
        end
      end

      -1  # No matching close found — not a code span
    end
  end
end
