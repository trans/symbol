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
    SYMBOL::VERSION.should eq("0.2.0")
  end

  describe "arithmetic" do
    it "adds integers" do
      result = eval("2 + 3")
      result.should be_a(Int64)
      result.should eq(5)
    end

    it "subtracts integers" do
      result = eval("10 - 3")
      result.should be_a(Int64)
      result.should eq(7)
    end

    it "multiplies integers" do
      result = eval("4 * 5")
      result.should be_a(Int64)
      result.should eq(20)
    end

    it "divides integers exactly" do
      result = eval("20 / 4")
      result.should be_a(Int64)
      result.should eq(5)
    end

    it "divides integers inexactly to float" do
      result = eval("7 / 2")
      result.should be_a(Float64)
      result.should eq(3.5)
    end

    it "modulo integers" do
      result = eval("7 % 3")
      result.should be_a(Int64)
      result.should eq(1)
    end

    it "exponentiation integers" do
      result = eval("2 ^ 3")
      result.should be_a(Int64)
      result.should eq(8)
    end

    it "division by zero returns infinity" do
      eval("1 / 0").should eq(Float64::INFINITY)
    end

    it "evaluates a single integer literal" do
      result = eval("42")
      result.should be_a(Int64)
      result.should eq(42)
    end

    it "evaluates a single float literal" do
      result = eval("3.14")
      result.should be_a(Float64)
      result.should eq(3.14)
    end

    it "handles negative numbers" do
      result = eval("-5 + 3")
      result.should be_a(Int64)
      result.should eq(-2)
    end
  end

  describe "type promotion" do
    it "int + float → float" do
      result = eval("2 + 3.5")
      result.should be_a(Float64)
      result.should eq(5.5)
    end

    it "float + int → float" do
      result = eval("3.5 + 2")
      result.should be_a(Float64)
      result.should eq(5.5)
    end

    it "float + float → float" do
      result = eval("1.5 + 2.5")
      result.should be_a(Float64)
      result.should eq(4.0)
    end

    it "int * float → float" do
      result = eval("3 * 2.0")
      result.should be_a(Float64)
      result.should eq(6.0)
    end

    it "int variable + int literal → float (float binding)" do
      result = eval("k + 1", {"k" => 5.0.as(SYMBOL::Tacit::TacitValue)})
      result.should be_a(Float64)
      result.should eq(6.0)
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

    it "unary negation ~ preserves int" do
      result = eval("~ 5")
      result.should be_a(Int64)
      result.should eq(-5)
    end

    it "unary negation ~ preserves float" do
      result = eval("~ 5.0")
      result.should be_a(Float64)
      result.should eq(-5.0)
    end
  end

  describe "variables" do
    it "resolves a bound float variable" do
      eval("k + 1", {"k" => 5.0.as(SYMBOL::Tacit::TacitValue)}).should eq(6.0)
    end

    it "resolves a bound int variable" do
      result = eval("k + 1", {"k" => 5_i64.as(SYMBOL::Tacit::TacitValue)})
      result.should be_a(Int64)
      result.should eq(6)
    end

    it "resolves multiple variables" do
      bindings = {
        "x" => 3_i64.as(SYMBOL::Tacit::TacitValue),
        "y" => 4_i64.as(SYMBOL::Tacit::TacitValue),
      }
      result = eval("x + y", bindings)
      result.should be_a(Int64)
      result.should eq(7)
    end

    it "returns Unbound for missing variable" do
      result = eval_result("unknown")
      result.should be_a(SYMBOL::Tacit::Unbound)
      result.as(SYMBOL::Tacit::Unbound).name.should eq("unknown")
    end
  end

  describe "ranges" do
    it "ascending range produces integers" do
      result = eval("1 .. 5")
      arr = result.as(Array(SYMBOL::Tacit::TacitValue))
      arr.size.should eq(5)
      arr[0].should be_a(Int64)
      arr.should eq([1_i64, 2_i64, 3_i64, 4_i64, 5_i64] of SYMBOL::Tacit::TacitValue)
    end

    it "descending range" do
      result = eval("5 .. 1")
      result.should eq([5_i64, 4_i64, 3_i64, 2_i64, 1_i64] of SYMBOL::Tacit::TacitValue)
    end

    it "single element range" do
      result = eval("3 .. 3")
      result.should eq([3_i64] of SYMBOL::Tacit::TacitValue)
    end
  end

  describe "lists" do
    it "evaluates a list of integers" do
      result = eval("[1, 2, 3]")
      arr = result.as(Array(SYMBOL::Tacit::TacitValue))
      arr[0].should be_a(Int64)
      arr.should eq([1_i64, 2_i64, 3_i64] of SYMBOL::Tacit::TacitValue)
    end

    it "evaluates a list with mixed types" do
      result = eval("[1, 2.5, 3]")
      arr = result.as(Array(SYMBOL::Tacit::TacitValue))
      arr[0].should be_a(Int64)
      arr[1].should be_a(Float64)
      arr[2].should be_a(Int64)
    end

    it "evaluates an empty list" do
      result = eval("[]")
      result.should eq([] of SYMBOL::Tacit::TacitValue)
    end
  end

  describe "aggregation" do
    it "sum Σ of integers" do
      result = eval("Σ [1, 2, 3, 4]")
      result.should be_a(Int64)
      result.should eq(10)
    end

    it "sum Σ of mixed promotes to float" do
      result = eval("Σ [1, 2.0, 3]")
      result.should be_a(Float64)
    end

    it "product Π of integers" do
      result = eval("Π [1, 2, 3, 4]")
      result.should be_a(Int64)
      result.should eq(24)
    end

    it "count # returns integer" do
      result = eval("# [10, 20, 30]")
      result.should be_a(Int64)
      result.should eq(3)
    end

    it "max ⌈ of integer array" do
      result = eval("⌈ [3, 1, 4, 1, 5]")
      result.should be_a(Int64)
      result.should eq(5)
    end

    it "min ⌊ of integer array" do
      result = eval("⌊ [3, 1, 4, 1, 5]")
      result.should be_a(Int64)
      result.should eq(1)
    end
  end

  describe "ceiling/floor (scalar)" do
    it "⌈ ceiling of float" do
      result = eval("⌈ 3.2")
      result.should be_a(Int64)
      result.should eq(4)
    end

    it "⌈ ceiling of negative float" do
      result = eval("⌈ -2.7")
      result.should be_a(Int64)
      result.should eq(-2)
    end

    it "⌈ of integer is identity" do
      result = eval("⌈ 5")
      result.should be_a(Int64)
      result.should eq(5)
    end

    it "⌊ floor of float" do
      result = eval("⌊ 3.8")
      result.should be_a(Int64)
      result.should eq(3)
    end

    it "⌊ floor of negative float" do
      result = eval("⌊ -2.3")
      result.should be_a(Int64)
      result.should eq(-3)
    end

    it "⌊ of integer is identity" do
      result = eval("⌊ 5")
      result.should be_a(Int64)
      result.should eq(5)
    end
  end

  describe "structural operators" do
    it "concat ><" do
      result = eval("[1, 2] >< [3, 4]")
      result.should eq([1_i64, 2_i64, 3_i64, 4_i64] of SYMBOL::Tacit::TacitValue)
    end

    it "wrap <>" do
      result = eval("1 <> 2")
      result.should eq([1_i64, 2_i64] of SYMBOL::Tacit::TacitValue)
    end

    it "cons +> (prepend)" do
      result = eval("0 +> [1, 2, 3]")
      result.should eq([0_i64, 1_i64, 2_i64, 3_i64] of SYMBOL::Tacit::TacitValue)
    end

    it "snoc <+ (append)" do
      result = eval("[1, 2, 3] <+ 4")
      result.should eq([1_i64, 2_i64, 3_i64, 4_i64] of SYMBOL::Tacit::TacitValue)
    end

    it "index @ (1-indexed)" do
      result = eval("2 @ [10, 20, 30]")
      result.should be_a(Int64)
      result.should eq(20)
    end

    it "index @ negative (from end)" do
      result = eval("-1 @ [10, 20, 30]")
      result.should be_a(Int64)
      result.should eq(30)
    end

    it "reverse ⌽" do
      result = eval("⌽ [1, 2, 3]")
      result.should eq([3_i64, 2_i64, 1_i64] of SYMBOL::Tacit::TacitValue)
    end

    it "take ↑" do
      result = eval("2 ↑ [10, 20, 30, 40]")
      result.should eq([10_i64, 20_i64] of SYMBOL::Tacit::TacitValue)
    end

    it "drop ↓" do
      result = eval("2 ↓ [10, 20, 30, 40]")
      result.should eq([30_i64, 40_i64] of SYMBOL::Tacit::TacitValue)
    end

    it "zip ~>" do
      result = eval("[1, 2, 3] ~> [4, 5, 6]")
      result.should eq([1_i64, 4_i64, 2_i64, 5_i64, 3_i64, 6_i64] of SYMBOL::Tacit::TacitValue)
    end
  end

  describe "vectorization" do
    it "adds scalar to array (int)" do
      result = eval("[1, 2, 3] + 10")
      arr = result.as(Array(SYMBOL::Tacit::TacitValue))
      arr[0].should be_a(Int64)
      arr.should eq([11_i64, 12_i64, 13_i64] of SYMBOL::Tacit::TacitValue)
    end

    it "multiplies arrays element-wise (int)" do
      result = eval("[2, 3, 4] * [10, 20, 30]")
      result.should eq([20_i64, 60_i64, 120_i64] of SYMBOL::Tacit::TacitValue)
    end

    it "scalar minus array (int)" do
      result = eval("10 - [1, 2, 3]")
      result.should eq([9_i64, 8_i64, 7_i64] of SYMBOL::Tacit::TacitValue)
    end

    it "int array + float scalar promotes to float" do
      result = eval("[1, 2, 3] + 0.5")
      arr = result.as(Array(SYMBOL::Tacit::TacitValue))
      arr[0].should be_a(Float64)
      arr.should eq([1.5, 2.5, 3.5] of SYMBOL::Tacit::TacitValue)
    end
  end

  describe "grouped expressions" do
    it "evaluates parenthesized sub-expression" do
      result = eval("2 * (3 + 4)")
      result.should be_a(Int64)
      result.should eq(14)
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

    it "bitwise OR returns int" do
      result = eval("5 [+] 3")
      result.should be_a(Int64)
      result.should eq(7)
    end

    it "bitwise AND returns int" do
      result = eval("5 [*] 3")
      result.should be_a(Int64)
      result.should eq(1)
    end
  end
end
