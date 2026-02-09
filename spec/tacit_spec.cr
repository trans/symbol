require "./spec_helper"

# Helper to create a properly typed array of expression terms
private def terms(*args : SYMBOL::AST::ExprTerm) : Array(SYMBOL::AST::ExprTerm)
  result = [] of SYMBOL::AST::ExprTerm
  args.each { |a| result << a }
  result
end

describe SYMBOL::Tacit::Evaluator do
  describe "#eval" do
    it "evaluates a simple literal" do
      expr = SYMBOL::AST::Expression.new(terms(
        SYMBOL::AST::ExprLiteral.new(42.0),
      ))
      evaluator = SYMBOL::Tacit::Evaluator.new
      result = evaluator.eval(expr, {} of String => SYMBOL::Tacit::TacitValue)
      result.should be_a(SYMBOL::Tacit::Resolved)
      result.as(SYMBOL::Tacit::Resolved).value.should eq 42.0
    end

    it "evaluates addition right-to-left" do
      # Expression: 3 + 5 should give 8
      # In RRPN: [3, +, 5] evaluates right-to-left
      expr = SYMBOL::AST::Expression.new(terms(
        SYMBOL::AST::ExprLiteral.new(3.0),
        SYMBOL::AST::ExprOperator.new("+", 2),
        SYMBOL::AST::ExprLiteral.new(5.0),
      ))
      evaluator = SYMBOL::Tacit::Evaluator.new
      result = evaluator.eval(expr, {} of String => SYMBOL::Tacit::TacitValue)
      result.should be_a(SYMBOL::Tacit::Resolved)
      result.as(SYMBOL::Tacit::Resolved).value.should eq 8.0
    end

    it "evaluates subtraction" do
      expr = SYMBOL::AST::Expression.new(terms(
        SYMBOL::AST::ExprLiteral.new(10.0),
        SYMBOL::AST::ExprOperator.new("-", 2),
        SYMBOL::AST::ExprLiteral.new(3.0),
      ))
      evaluator = SYMBOL::Tacit::Evaluator.new
      result = evaluator.eval(expr, {} of String => SYMBOL::Tacit::TacitValue)
      result.should be_a(SYMBOL::Tacit::Resolved)
      result.as(SYMBOL::Tacit::Resolved).value.should eq 7.0
    end

    it "evaluates multiplication" do
      expr = SYMBOL::AST::Expression.new(terms(
        SYMBOL::AST::ExprLiteral.new(4.0),
        SYMBOL::AST::ExprOperator.new("*", 2),
        SYMBOL::AST::ExprLiteral.new(5.0),
      ))
      evaluator = SYMBOL::Tacit::Evaluator.new
      result = evaluator.eval(expr, {} of String => SYMBOL::Tacit::TacitValue)
      result.should be_a(SYMBOL::Tacit::Resolved)
      result.as(SYMBOL::Tacit::Resolved).value.should eq 20.0
    end

    it "evaluates division" do
      expr = SYMBOL::AST::Expression.new(terms(
        SYMBOL::AST::ExprLiteral.new(20.0),
        SYMBOL::AST::ExprOperator.new("/", 2),
        SYMBOL::AST::ExprLiteral.new(4.0),
      ))
      evaluator = SYMBOL::Tacit::Evaluator.new
      result = evaluator.eval(expr, {} of String => SYMBOL::Tacit::TacitValue)
      result.should be_a(SYMBOL::Tacit::Resolved)
      result.as(SYMBOL::Tacit::Resolved).value.should eq 5.0
    end

    it "evaluates comparison operators" do
      # 5 > 3 should be true
      expr = SYMBOL::AST::Expression.new(terms(
        SYMBOL::AST::ExprLiteral.new(5.0),
        SYMBOL::AST::ExprOperator.new(">", 2),
        SYMBOL::AST::ExprLiteral.new(3.0),
      ))
      evaluator = SYMBOL::Tacit::Evaluator.new
      result = evaluator.eval(expr, {} of String => SYMBOL::Tacit::TacitValue)
      result.should be_a(SYMBOL::Tacit::Resolved)
      result.as(SYMBOL::Tacit::Resolved).value.should eq true
    end

    it "evaluates equality" do
      expr = SYMBOL::AST::Expression.new(terms(
        SYMBOL::AST::ExprLiteral.new(5.0),
        SYMBOL::AST::ExprOperator.new("==", 2),
        SYMBOL::AST::ExprLiteral.new(5.0),
      ))
      evaluator = SYMBOL::Tacit::Evaluator.new
      result = evaluator.eval(expr, {} of String => SYMBOL::Tacit::TacitValue)
      result.should be_a(SYMBOL::Tacit::Resolved)
      result.as(SYMBOL::Tacit::Resolved).value.should eq true
    end

    it "evaluates logical not" do
      expr = SYMBOL::AST::Expression.new(terms(
        SYMBOL::AST::ExprOperator.new("!", 1),
        SYMBOL::AST::ExprLiteral.new(0.0), # false
      ))
      evaluator = SYMBOL::Tacit::Evaluator.new
      result = evaluator.eval(expr, {} of String => SYMBOL::Tacit::TacitValue)
      result.should be_a(SYMBOL::Tacit::Resolved)
      result.as(SYMBOL::Tacit::Resolved).value.should eq true
    end

    it "resolves variables from bindings" do
      # k + 1 with k=5 should give 6
      expr = SYMBOL::AST::Expression.new(terms(
        SYMBOL::AST::ExprVariable.new("k"),
        SYMBOL::AST::ExprOperator.new("+", 2),
        SYMBOL::AST::ExprLiteral.new(1.0),
      ))
      bindings = {"k" => 5.0.as(SYMBOL::Tacit::TacitValue)}
      evaluator = SYMBOL::Tacit::Evaluator.new
      result = evaluator.eval(expr, bindings)
      result.should be_a(SYMBOL::Tacit::Resolved)
      result.as(SYMBOL::Tacit::Resolved).value.should eq 6.0
    end

    it "returns unbound for missing variables" do
      expr = SYMBOL::AST::Expression.new(terms(
        SYMBOL::AST::ExprVariable.new("unknown"),
      ))
      evaluator = SYMBOL::Tacit::Evaluator.new
      result = evaluator.eval(expr, {} of String => SYMBOL::Tacit::TacitValue)
      result.should be_a(SYMBOL::Tacit::Unbound)
      result.as(SYMBOL::Tacit::Unbound).name.should eq "unknown"
    end

    it "creates suspended computation for partial application" do
      # Just "+ 5" without left argument
      expr = SYMBOL::AST::Expression.new(terms(
        SYMBOL::AST::ExprOperator.new("+", 2),
        SYMBOL::AST::ExprLiteral.new(5.0),
      ))
      evaluator = SYMBOL::Tacit::Evaluator.new
      result = evaluator.eval(expr, {} of String => SYMBOL::Tacit::TacitValue)
      result.should be_a(SYMBOL::Tacit::Suspended)
      suspended = result.as(SYMBOL::Tacit::Suspended)
      suspended.op.should eq "+"
      suspended.needs_args.should eq 1
    end
  end
end
