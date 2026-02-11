# SYMBOL Expression Lexer

module SYMBOL
  enum TokenType
    # Literals
    Number
    String
    Identifier
    True
    False

    # Operators
    Plus
    Minus
    Star
    Slash
    Percent
    Caret       # ^
    Equals
    NotEq
    LessThan
    GreaterThan
    LessEq
    GreaterEq
    Bang
    Question
    AtSign
    Hash        # #
    Tilde       # ~
    Dollar      # $

    # Unicode operators
    Sum         # Σ
    Product     # Π
    NotEqual    # ≠
    LessEqual   # ≤
    GreaterEqual # ≥
    CeilMax     # ⌈
    FloorMin    # ⌊
    Take        # ↑
    Drop        # ↓
    Reverse     # ⌽

    # Assignment
    Assign      # =

    # Range
    Range       # ..

    # Statement separator
    Period      # .

    # Structural operators
    Concat      # ><
    Wrap        # <>
    Cons        # +>
    Snoc        # <+
    Zip         # ~>
    Piz         # <~
    RemoveBack  # ->
    RemoveFront # <-
    RemoveBoth  # <->

    # Wrapped operators (bitwise)
    BitOr       # [+]
    BitAnd      # [*]
    BitXor      # [-]
    BitNot      # [~]

    # Delimiters
    LParen
    RParen
    LBracket
    RBracket
    LBrace
    RBrace
    Comma
    Semicolon

    # Special
    EOF
    Error
  end

  class Token
    property type : TokenType
    property value : String
    property line : Int32
    property column : Int32

    def initialize(@type, @value = "", @line = 1, @column = 1)
    end

    def to_s(io : IO) : Nil
      io << type << "(" << value << ")"
    end
  end

  class Lexer
    @source : String
    @pos : Int32 = 0
    @line : Int32 = 1
    @column : Int32 = 1

    def initialize(@source)
    end

    def tokenize : Array(Token)
      tokens = [] of Token
      while !at_end?
        skip_whitespace
        break if at_end?
        tokens << next_token
      end
      tokens << Token.new(TokenType::EOF, "", @line, @column)
      tokens
    end

    private def next_token : Token
      start_col = @column
      c = advance

      case c
      when '+'
        if peek == '>'
          advance
          Token.new(TokenType::Cons, "+>", @line, start_col)
        else
          Token.new(TokenType::Plus, "+", @line, start_col)
        end
      when '-'
        if peek == '>'
          advance
          Token.new(TokenType::RemoveBack, "->", @line, start_col)
        elsif peek.ascii_number?
          number(c, start_col)
        else
          Token.new(TokenType::Minus, "-", @line, start_col)
        end
      when '*'
        Token.new(TokenType::Star, "*", @line, start_col)
      when '/'
        Token.new(TokenType::Slash, "/", @line, start_col)
      when '%'
        Token.new(TokenType::Percent, "%", @line, start_col)
      when '^'
        Token.new(TokenType::Caret, "^", @line, start_col)
      when '='
        if peek == '='
          advance
          Token.new(TokenType::Equals, "==", @line, start_col)
        else
          Token.new(TokenType::Assign, "=", @line, start_col)
        end
      when '!'
        if peek == '='
          advance
          Token.new(TokenType::NotEq, "!=", @line, start_col)
        else
          Token.new(TokenType::Bang, "!", @line, start_col)
        end
      when '<'
        if peek == '-' && peek_next == '>'
          advance; advance
          Token.new(TokenType::RemoveBoth, "<->", @line, start_col)
        elsif peek == '-'
          advance
          Token.new(TokenType::RemoveFront, "<-", @line, start_col)
        elsif peek == '>'
          advance
          Token.new(TokenType::Wrap, "<>", @line, start_col)
        elsif peek == '+'
          advance
          Token.new(TokenType::Snoc, "<+", @line, start_col)
        elsif peek == '~'
          advance
          Token.new(TokenType::Piz, "<~", @line, start_col)
        elsif peek == '='
          advance
          Token.new(TokenType::LessEq, "<=", @line, start_col)
        else
          Token.new(TokenType::LessThan, "<", @line, start_col)
        end
      when '>'
        if peek == '<'
          advance
          Token.new(TokenType::Concat, "><", @line, start_col)
        elsif peek == '='
          advance
          Token.new(TokenType::GreaterEq, ">=", @line, start_col)
        else
          Token.new(TokenType::GreaterThan, ">", @line, start_col)
        end
      when '?'
        Token.new(TokenType::Question, "?", @line, start_col)
      when '@'
        Token.new(TokenType::AtSign, "@", @line, start_col)
      when '#'
        Token.new(TokenType::Hash, "#", @line, start_col)
      when '~'
        if peek == '>'
          advance
          Token.new(TokenType::Zip, "~>", @line, start_col)
        else
          Token.new(TokenType::Tilde, "~", @line, start_col)
        end
      when '$'
        Token.new(TokenType::Dollar, "$", @line, start_col)
      when '('
        Token.new(TokenType::LParen, "(", @line, start_col)
      when ')'
        Token.new(TokenType::RParen, ")", @line, start_col)
      when '['
        # Check for wrapped operators [+], [*], [-], [~]
        if peek == '+' && peek_next == ']'
          advance; advance
          Token.new(TokenType::BitOr, "[+]", @line, start_col)
        elsif peek == '*' && peek_next == ']'
          advance; advance
          Token.new(TokenType::BitAnd, "[*]", @line, start_col)
        elsif peek == '-' && peek_next == ']'
          advance; advance
          Token.new(TokenType::BitXor, "[-]", @line, start_col)
        elsif peek == '~' && peek_next == ']'
          advance; advance
          Token.new(TokenType::BitNot, "[~]", @line, start_col)
        else
          Token.new(TokenType::LBracket, "[", @line, start_col)
        end
      when ']'
        Token.new(TokenType::RBracket, "]", @line, start_col)
      when '{'
        Token.new(TokenType::LBrace, "{", @line, start_col)
      when '}'
        Token.new(TokenType::RBrace, "}", @line, start_col)
      when ','
        Token.new(TokenType::Comma, ",", @line, start_col)
      when ';'
        Token.new(TokenType::Semicolon, ";", @line, start_col)
      when '.'
        if peek == '.'
          advance
          Token.new(TokenType::Range, "..", @line, start_col)
        else
          Token.new(TokenType::Period, ".", @line, start_col)
        end
      when '"'
        string(start_col)
      when 'Σ'
        Token.new(TokenType::Sum, "Σ", @line, start_col)
      when 'Π'
        Token.new(TokenType::Product, "Π", @line, start_col)
      when '≠'
        Token.new(TokenType::NotEqual, "≠", @line, start_col)
      when '≤'
        Token.new(TokenType::LessEqual, "≤", @line, start_col)
      when '≥'
        Token.new(TokenType::GreaterEqual, "≥", @line, start_col)
      when '⌈'
        Token.new(TokenType::CeilMax, "⌈", @line, start_col)
      when '⌊'
        Token.new(TokenType::FloorMin, "⌊", @line, start_col)
      when '⊤'
        Token.new(TokenType::True, "⊤", @line, start_col)
      when '⊥'
        Token.new(TokenType::False, "⊥", @line, start_col)
      when '↑'
        Token.new(TokenType::Take, "↑", @line, start_col)
      when '↓'
        Token.new(TokenType::Drop, "↓", @line, start_col)
      when '⌽'
        Token.new(TokenType::Reverse, "⌽", @line, start_col)
      else
        if c.ascii_number?
          number(c, start_col)
        elsif c.ascii_letter? || c == '_'
          identifier(c, start_col)
        else
          Token.new(TokenType::Error, "Unexpected character: #{c}", @line, start_col)
        end
      end
    end

    private def number(first : Char, start_col : Int32) : Token
      has_dot = false
      value = String.build do |str|
        str << first
        while !at_end?
          if peek.ascii_number?
            str << advance
          elsif peek == '.' && !has_dot && peek_next.ascii_number?
            has_dot = true
            str << advance
          else
            break
          end
        end
      end
      Token.new(TokenType::Number, value, @line, start_col)
    end

    private def string(start_col : Int32) : Token
      value = String.build do |str|
        while !at_end? && peek != '"'
          if peek == '\\'
            advance
            if !at_end?
              case advance
              when 'n'  then str << '\n'
              when 't'  then str << '\t'
              when '\\' then str << '\\'
              when '"'  then str << '"'
              else
                str << '\\'
              end
            end
          else
            str << advance
          end
        end
      end
      advance if !at_end? # consume closing "
      Token.new(TokenType::String, value, @line, start_col)
    end

    private def identifier(first : Char, start_col : Int32) : Token
      value = String.build do |str|
        str << first
        while !at_end? && (peek.ascii_alphanumeric? || peek == '_')
          str << advance
        end
      end
      # Check for boolean literals
      case value
      when "true"
        Token.new(TokenType::True, value, @line, start_col)
      when "false"
        Token.new(TokenType::False, value, @line, start_col)
      else
        Token.new(TokenType::Identifier, value, @line, start_col)
      end
    end

    private def skip_whitespace
      while !at_end? && peek.ascii_whitespace?
        if peek == '\n'
          @line += 1
          @column = 0
        end
        advance
      end
    end

    private def at_end? : Bool
      @pos >= @source.size
    end

    private def peek : Char
      return '\0' if at_end?
      @source[@pos]
    end

    private def peek_next : Char
      return '\0' if @pos + 1 >= @source.size
      @source[@pos + 1]
    end

    private def advance : Char
      c = @source[@pos]
      @pos += 1
      @column += 1
      c
    end
  end
end
