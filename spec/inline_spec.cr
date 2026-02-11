require "./spec_helper"

private alias TV = SYMBOL::Tacit::TacitValue

describe SYMBOL::Inline do
  describe "basic evaluation" do
    it "evaluates a simple expression" do
      SYMBOL.inline("x is {{ 2 + 3 }}").should eq("x is 5")
    end

    it "evaluates with variable bindings" do
      bindings = {"x" => 10_i64.as(TV)}
      SYMBOL.inline("{{ x }}", bindings).should eq("10")
    end

    it "evaluates multiple expressions" do
      bindings = {"a" => 1_i64.as(TV), "b" => 2_i64.as(TV)}
      SYMBOL.inline("{{ a }} and {{ b }}", bindings).should eq("1 and 2")
    end

    it "passes through plain text unchanged" do
      SYMBOL.inline("plain text").should eq("plain text")
    end

    it "handles adjacent expressions" do
      SYMBOL.inline("{{ 1 }}{{ 2 }}").should eq("12")
    end

    it "trims whitespace in expressions" do
      SYMBOL.inline("{{  2 + 3  }}").should eq("5")
    end
  end

  describe "result formatting" do
    it "formats integers without decimal" do
      SYMBOL.inline("{{ 5 }}").should eq("5")
    end

    it "formats floats with decimal" do
      SYMBOL.inline("{{ 5.0 }}").should eq("5.0")
    end

    it "keeps decimal for fractional values" do
      SYMBOL.inline("{{ 1 / 3 }}").should_not eq("0")
    end

    it "formats arrays" do
      SYMBOL.inline("{{ [1, 2, 3] }}").should eq("[1, 2, 3]")
    end

    it "formats booleans" do
      SYMBOL.inline("{{ 5 == 5 }}").should eq("true")
      SYMBOL.inline("{{ 5 == 3 }}").should eq("false")
    end

    it "formats strings" do
      SYMBOL.inline(%({{ "hello" }})).should eq("hello")
    end
  end

  describe "code span passthrough" do
    it "does not evaluate inside code spans" do
      SYMBOL.inline("use `{{ expr }}` in code").should eq("use `{{ expr }}` in code")
    end

    it "handles double-backtick code spans" do
      SYMBOL.inline("use `` {{ expr }} `` here").should eq("use `` {{ expr }} `` here")
    end

    it "evaluates outside code spans" do
      SYMBOL.inline("`code` and {{ 2 + 3 }}").should eq("`code` and 5")
    end
  end

  describe "code fence passthrough" do
    it "does not evaluate inside code fences" do
      text = "before\n```\n{{ 2 + 3 }}\n```\nafter {{ 1 }}"
      SYMBOL.inline(text).should eq("before\n```\n{{ 2 + 3 }}\n```\nafter 1")
    end

    it "handles code fences with language tag" do
      text = "```crystal\n{{ x }}\n```"
      SYMBOL.inline(text).should eq("```crystal\n{{ x }}\n```")
    end

    it "handles code fences with more than 3 backticks" do
      text = "````\n{{ x }}\n````"
      SYMBOL.inline(text).should eq("````\n{{ x }}\n````")
    end
  end

  describe "escaping" do
    it "emits literal {{ for escaped expression" do
      SYMBOL.inline("literal \\{{ not eval }}").should eq("literal {{ not eval }}")
    end

    it "does not evaluate escaped expressions" do
      SYMBOL.inline("\\{{ 2 + 3 }}").should eq("{{ 2 + 3 }}")
    end
  end

  describe "error handling" do
    it "leaves unbound variables unchanged" do
      SYMBOL.inline("{{ unknown }}").should eq("{{ unknown }}")
    end

    it "leaves parse errors unchanged" do
      SYMBOL.inline("{{ 2 + + }}").should eq("{{ 2 + + }}")
    end

    it "leaves empty expressions unchanged" do
      SYMBOL.inline("{{ }}").should eq("{{ }}")
    end

    it "leaves unclosed {{ as literal" do
      SYMBOL.inline("start {{ no close").should eq("start {{ no close")
    end
  end

  describe "format helper" do
    it "formats nil as empty string" do
      SYMBOL::Inline.format(nil).should eq("")
    end

    it "formats nested arrays" do
      # Use SYMBOL.eval to produce a nested structure naturally
      result = SYMBOL.eval("[1, 2] <> [3, 4]")
      val = result.as(SYMBOL::Tacit::Resolved).value
      SYMBOL::Inline.format(val).should eq("[[1, 2], [3, 4]]")
    end
  end
end
