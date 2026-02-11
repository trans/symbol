require "./spec_helper"

private alias TV = SYMBOL::Tacit::TacitValue

# Helper to run eval(program: true) and extract resolved value
private def eval_multi(source : String, bindings = {} of String => TV) : TV
  result = SYMBOL.eval(source, bindings, program: true)
  result.as(SYMBOL::Tacit::Resolved).value
end

describe "multi-statement eval" do
  describe "single expression (no assignment)" do
    it "evaluates a simple expression" do
      eval_multi("2 + 3").should eq(5)
    end

    it "evaluates a single literal" do
      eval_multi("42").should eq(42)
    end
  end

  describe "assignment" do
    it "assigns and returns the value" do
      bindings = {} of String => TV
      eval_multi("x = 4.", bindings).should eq(4)
      bindings["x"].should eq(4)
    end

    it "assigns and uses in next statement" do
      eval_multi("x = 4. x + 2.").should eq(6)
    end

    it "chains assignments" do
      bindings = {} of String => TV
      eval_multi("x = 3. y = x * 2. y + 1.", bindings).should eq(7)
      bindings["x"].should eq(3)
      bindings["y"].should eq(6)
    end
  end

  describe "trailing period" do
    it "works without trailing period" do
      eval_multi("x = 4. x + 2").should eq(6)
    end

    it "works with trailing period" do
      eval_multi("x = 4. x + 2.").should eq(6)
    end
  end

  describe "mixed types" do
    it "handles float assignment" do
      eval_multi("x = 3.14. ⌊ x.").should eq(3)
    end

    it "handles string assignment" do
      bindings = {} of String => TV
      eval_multi("s = \"hello\".", bindings).should eq("hello")
      bindings["s"].should eq("hello")
    end

    it "handles boolean assignment" do
      bindings = {} of String => TV
      eval_multi("b = true.", bindings).should eq(true)
      bindings["b"].should eq(true)
    end

    it "handles list assignment" do
      bindings = {} of String => TV
      result = eval_multi("xs = [1, 2, 3].", bindings)
      result.should eq([1_i64, 2_i64, 3_i64] of TV)
    end
  end

  describe "empty program" do
    it "returns nil for empty periods" do
      result = SYMBOL.eval(". .", program: true)
      result.as(SYMBOL::Tacit::Resolved).value.should be_nil
    end

    it "returns nil for empty string" do
      result = SYMBOL.eval("", program: true)
      result.as(SYMBOL::Tacit::Resolved).value.should be_nil
    end
  end

  describe "bindings mutation" do
    it "mutates the provided bindings hash" do
      bindings = {} of String => TV
      SYMBOL.eval("x = 10. y = 20.", bindings, program: true)
      bindings["x"].should eq(10)
      bindings["y"].should eq(20)
    end

    it "can use pre-existing bindings" do
      bindings = {"x" => 5_i64.as(TV)}
      eval_multi("x + 10", bindings).should eq(15)
    end

    it "can override pre-existing bindings" do
      bindings = {"x" => 5_i64.as(TV)}
      eval_multi("x = 10. x", bindings).should eq(10)
      bindings["x"].should eq(10)
    end
  end

  describe "= rejected in expression context" do
    it "raises parse error for = in SYMBOL.eval" do
      expect_raises(SYMBOL::ParseError, /assignment/i) do
        SYMBOL.eval("x = 5")
      end
    end
  end
end
