# SYMBOL Expression Parser

require "./lexer"
require "./ast"

module SYMBOL
  class ParseError < Exception
    property line : Int32
    property column : Int32

    def initialize(message, @line, @column)
      super("#{line}:#{column}: #{message}")
    end
  end

  class Parser
    @tokens : Array(Token)
    @pos : Int32 = 0

    def initialize(@tokens)
    end

    def self.parse(source : String) : AST::Expression
      tokens = Lexer.new(source).tokenize
      new(tokens).parse
    end

    def parse : AST::Expression
      terms = [] of AST::ExprTerm
      while !at_end?
        terms << parse_term
      end
      AST::Expression.new(terms)
    end

    private def parse_term : AST::ExprTerm
      tok = current

      case tok.type
      when TokenType::Number
        advance
        AST::ExprLiteral.new(tok.value.to_f64)

      when TokenType::String
        advance
        AST::ExprLiteral.new(tok.value)

      when TokenType::Identifier
        advance
        AST::ExprVariable.new(tok.value)

      when TokenType::True
        advance
        AST::ExprLiteral.new(true)

      when TokenType::False
        advance
        AST::ExprLiteral.new(false)

      when TokenType::Plus
        advance
        AST::ExprOperator.new("+", 2)

      when TokenType::Minus
        advance
        AST::ExprOperator.new("-", 2)

      when TokenType::Star
        advance
        AST::ExprOperator.new("*", 2)

      when TokenType::Slash
        advance
        AST::ExprOperator.new("/", 2)

      when TokenType::Percent
        advance
        AST::ExprOperator.new("%", 2)

      when TokenType::Caret
        advance
        AST::ExprOperator.new("^", 2)

      when TokenType::Range
        advance
        AST::ExprOperator.new("..", 2)

      when TokenType::Equals
        advance
        AST::ExprOperator.new("=", 2)

      when TokenType::NotEq, TokenType::NotEqual
        advance
        AST::ExprOperator.new("≠", 2)

      when TokenType::LessThan
        advance
        AST::ExprOperator.new("<", 2)

      when TokenType::GreaterThan
        advance
        AST::ExprOperator.new(">", 2)

      when TokenType::LessEq, TokenType::LessEqual
        advance
        AST::ExprOperator.new("≤", 2)

      when TokenType::GreaterEq, TokenType::GreaterEqual
        advance
        AST::ExprOperator.new("≥", 2)

      when TokenType::Bang
        advance
        AST::ExprOperator.new("!", 1)

      when TokenType::Question
        advance
        AST::ExprOperator.new("?", 2)

      when TokenType::AtSign
        advance
        AST::ExprOperator.new("@", 2)

      when TokenType::Hash
        advance
        AST::ExprOperator.new("#", 1)

      when TokenType::Tilde
        advance
        AST::ExprOperator.new("~", 1)

      when TokenType::Sum
        advance
        AST::ExprOperator.new("Σ", 1)

      when TokenType::Product
        advance
        AST::ExprOperator.new("Π", 1)

      when TokenType::CeilMax
        advance
        AST::ExprOperator.new("⌈", 1)

      when TokenType::FloorMin
        advance
        AST::ExprOperator.new("⌊", 1)

      # Wrapped bitwise operators
      when TokenType::BitOr
        advance
        AST::ExprOperator.new("[+]", 2)

      when TokenType::BitAnd
        advance
        AST::ExprOperator.new("[*]", 2)

      when TokenType::BitXor
        advance
        AST::ExprOperator.new("[-]", 2)

      when TokenType::BitNot
        advance
        AST::ExprOperator.new("[~]", 1)

      # Structural operators
      when TokenType::Concat
        advance
        AST::ExprOperator.new("><", 2)

      when TokenType::Wrap
        advance
        AST::ExprOperator.new("<>", 2)

      when TokenType::Cons
        advance
        AST::ExprOperator.new("+>", 2)

      when TokenType::Snoc
        advance
        AST::ExprOperator.new("<+", 2)

      when TokenType::Zip
        advance
        AST::ExprOperator.new("~>", 2)

      when TokenType::Piz
        advance
        AST::ExprOperator.new("<~", 2)

      when TokenType::RemoveBack
        advance
        AST::ExprOperator.new("->", 2)

      when TokenType::RemoveFront
        advance
        AST::ExprOperator.new("<-", 2)

      when TokenType::RemoveBoth
        advance
        AST::ExprOperator.new("<->", 2)

      when TokenType::Take
        advance
        AST::ExprOperator.new("↑", 2)

      when TokenType::Drop
        advance
        AST::ExprOperator.new("↓", 2)

      when TokenType::Reverse
        advance
        AST::ExprOperator.new("⌽", 1)

      when TokenType::LParen
        parse_grouped

      when TokenType::LBracket
        parse_list

      when TokenType::EOF
        raise ParseError.new("Unexpected end of input", tok.line, tok.column)

      else
        raise ParseError.new("Unexpected token: #{tok.type}", tok.line, tok.column)
      end
    end

    private def parse_grouped : AST::ExprTerm
      advance # consume (
      terms = [] of AST::ExprTerm

      while !check(TokenType::RParen) && !at_end?
        terms << parse_term
      end

      expect(TokenType::RParen)
      # Return a grouped expression that evaluates as a unit
      AST::ExprGrouped.new(terms)
    end

    private def parse_list : AST::ExprTerm
      advance # consume [
      items = [] of AST::ExprTerm

      while !check(TokenType::RBracket) && !at_end?
        tok = current
        case tok.type
        when TokenType::Number
          advance
          items << AST::ExprLiteral.new(tok.value.to_f64)
        when TokenType::String
          advance
          items << AST::ExprLiteral.new(tok.value)
        when TokenType::True
          advance
          items << AST::ExprLiteral.new(true)
        when TokenType::False
          advance
          items << AST::ExprLiteral.new(false)
        when TokenType::Identifier
          advance
          items << AST::ExprVariable.new(tok.value)
        when TokenType::LBracket
          items << parse_list # nested list
        when TokenType::Comma
          advance
        else
          raise ParseError.new("Expected value in list, got #{tok.type}", tok.line, tok.column)
        end
      end

      expect(TokenType::RBracket)
      AST::ExprList.new(items)
    end

    private def current : Token
      @tokens[@pos]
    end

    private def at_end? : Bool
      current.type == TokenType::EOF
    end

    private def check(type : TokenType) : Bool
      current.type == type
    end

    private def advance : Token
      tok = current
      @pos += 1 unless at_end?
      tok
    end

    private def expect(type : TokenType) : Token
      if check(type)
        advance
      else
        raise ParseError.new("Expected #{type}, got #{current.type}", current.line, current.column)
      end
    end
  end
end
