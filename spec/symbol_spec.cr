require "./spec_helper"

# Helper to extract resolved value from eval result
private def eval(expr : String, bindings = {} of String => SYMBOL::Tacit::TacitValue) : SYMBOL::Tacit::TacitValue
  result = SYMBOL.eval(expr, bindings)
  result.as(SYMBOL::Tacit::Resolved).value
end

private def eval_result(expr : String, bindings = {} of String => SYMBOL::Tacit::TacitValue) : SYMBOL::Tacit::EvalResult
  SYMBOL.eval(expr, bindings)
end

describe SYMBOL do
  it "has a version" do
    SYMBOL::VERSION.should eq("0.1.0")
  end

  describe "arithmetic" do
    it "adds" do
      eval("2 + 3").should eq(5.0)
    end

    it "subtracts" do
      eval("10 - 3").should eq(7.0)
    end

    it "multiplies" do
      eval("4 * 5").should eq(20.0)
    end

    it "divides" do
      eval("20 / 4").should eq(5.0)
    end

    it "modulo" do
      eval("7 % 3").should eq(1.0)
    end

    it "exponentiation" do
      eval("2 ^ 3").should eq(8.0)
    end

    it "division by zero returns infinity" do
      eval("1 / 0").should eq(Float64::INFINITY)
    end

    it "evaluates a single literal" do
      eval("42").should eq(42.0)
    end

    it "handles negative numbers" do
      eval("-5 + 3").should eq(-2.0)
    end
  end

  describe "comparison" do
    it "equal (true)" do
      eval("5 == 5").should eq(true)
    end

    it "equal (false)" do
      eval("5 == 3").should eq(false)
    end

    it "not equal" do
      eval("5 != 3").should eq(true)
    end

    it "less than" do
      eval("3 < 5").should eq(true)
    end

    it "greater than" do
      eval("5 > 3").should eq(true)
    end

    it "less than or equal" do
      eval("3 <= 3").should eq(true)
    end

    it "greater than or equal" do
      eval("5 >= 6").should eq(false)
    end
  end

  describe "logic" do
    it "negates falsy" do
      eval("! 0").should eq(true)
    end

    it "negates truthy" do
      eval("! 1").should eq(false)
    end

    it "unary negation ~" do
      eval("~ 5").should eq(-5.0)
    end
  end

  describe "variables" do
    it "resolves a bound variable" do
      eval("k + 1", {"k" => 5.0.as(SYMBOL::Tacit::TacitValue)}).should eq(6.0)
    end

    it "resolves multiple variables" do
      bindings = {
        "x" => 3.0.as(SYMBOL::Tacit::TacitValue),
        "y" => 4.0.as(SYMBOL::Tacit::TacitValue),
      }
      eval("x + y", bindings).should eq(7.0)
    end

    it "returns Unbound for missing variable" do
      result = eval_result("unknown")
      result.should be_a(SYMBOL::Tacit::Unbound)
      result.as(SYMBOL::Tacit::Unbound).name.should eq("unknown")
    end
  end

  describe "ranges" do
    it "ascending range" do
      result = eval("1 .. 5")
      result.should eq([1.0, 2.0, 3.0, 4.0, 5.0] of SYMBOL::Tacit::TacitValue)
    end

    it "descending range" do
      result = eval("5 .. 1")
      result.should eq([5.0, 4.0, 3.0, 2.0, 1.0] of SYMBOL::Tacit::TacitValue)
    end

    it "single element range" do
      result = eval("3 .. 3")
      result.should eq([3.0] of SYMBOL::Tacit::TacitValue)
    end
  end

  describe "lists" do
    it "evaluates a list literal" do
      result = eval("[1, 2, 3]")
      result.should eq([1.0, 2.0, 3.0] of SYMBOL::Tacit::TacitValue)
    end

    it "evaluates an empty list" do
      result = eval("[]")
      result.should eq([] of SYMBOL::Tacit::TacitValue)
    end
  end

  describe "aggregation" do
    it "sum Σ" do
      eval("Σ [1, 2, 3, 4]").should eq(10.0)
    end

    it "product Π" do
      eval("Π [1, 2, 3, 4]").should eq(24.0)
    end

    it "count #" do
      eval("# [10, 20, 30]").should eq(3.0)
    end

    it "max ⌈" do
      eval("⌈ [3, 1, 4, 1, 5]").should eq(5.0)
    end

    it "min ⌊" do
      eval("⌊ [3, 1, 4, 1, 5]").should eq(1.0)
    end
  end

  describe "structural operators" do
    it "concat ><" do
      result = eval("[1, 2] >< [3, 4]")
      result.should eq([1.0, 2.0, 3.0, 4.0] of SYMBOL::Tacit::TacitValue)
    end

    it "wrap <>" do
      result = eval("1 <> 2")
      result.should eq([1.0, 2.0] of SYMBOL::Tacit::TacitValue)
    end

    it "cons +> (prepend)" do
      result = eval("0 +> [1, 2, 3]")
      result.should eq([0.0, 1.0, 2.0, 3.0] of SYMBOL::Tacit::TacitValue)
    end

    it "snoc <+ (append)" do
      result = eval("[1, 2, 3] <+ 4")
      result.should eq([1.0, 2.0, 3.0, 4.0] of SYMBOL::Tacit::TacitValue)
    end

    it "index @ (1-indexed)" do
      eval("2 @ [10, 20, 30]").should eq(20.0)
    end

    it "index @ negative (from end)" do
      eval("-1 @ [10, 20, 30]").should eq(30.0)
    end

    it "reverse ⌽" do
      result = eval("⌽ [1, 2, 3]")
      result.should eq([3.0, 2.0, 1.0] of SYMBOL::Tacit::TacitValue)
    end

    it "take ↑" do
      result = eval("2 ↑ [10, 20, 30, 40]")
      result.should eq([10.0, 20.0] of SYMBOL::Tacit::TacitValue)
    end

    it "drop ↓" do
      result = eval("2 ↓ [10, 20, 30, 40]")
      result.should eq([30.0, 40.0] of SYMBOL::Tacit::TacitValue)
    end

    it "zip ~>" do
      result = eval("[1, 2, 3] ~> [4, 5, 6]")
      result.should eq([1.0, 4.0, 2.0, 5.0, 3.0, 6.0] of SYMBOL::Tacit::TacitValue)
    end
  end

  describe "vectorization" do
    it "adds scalar to array" do
      result = eval("[1, 2, 3] + 10")
      result.should eq([11.0, 12.0, 13.0] of SYMBOL::Tacit::TacitValue)
    end

    it "multiplies arrays element-wise" do
      result = eval("[2, 3, 4] * [10, 20, 30]")
      result.should eq([20.0, 60.0, 120.0] of SYMBOL::Tacit::TacitValue)
    end

    it "scalar minus array" do
      result = eval("10 - [1, 2, 3]")
      result.should eq([9.0, 8.0, 7.0] of SYMBOL::Tacit::TacitValue)
    end
  end

  describe "grouped expressions" do
    it "evaluates parenthesized sub-expression" do
      eval("2 * (3 + 4)").should eq(14.0)
    end
  end

  describe "partial application" do
    it "creates suspended computation for missing left arg" do
      result = eval_result("+ 5")
      result.should be_a(SYMBOL::Tacit::Suspended)
      result.as(SYMBOL::Tacit::Suspended).op.should eq("+")
      result.as(SYMBOL::Tacit::Suspended).needs_args.should eq(1)
    end
  end

  describe "boolean literals" do
    it "true" do
      eval("true").should eq(true)
    end

    it "false" do
      eval("false").should eq(false)
    end
  end

  describe "strings" do
    it "evaluates a string literal" do
      eval("\"hello\"").should eq("hello")
    end
  end

  describe "bitwise" do
    it "boolean OR [+]" do
      eval("true [+] false").should eq(true)
    end

    it "boolean AND [*]" do
      eval("true [*] false").should eq(false)
    end

    it "boolean XOR [-]" do
      eval("true [-] true").should eq(false)
    end
  end
end
