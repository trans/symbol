require "./spec_helper"

# Helper to create typed hash for struct attrs
private def attrs(**args) : Hash(String, SYMBOL::Logic::Term)
  result = {} of String => SYMBOL::Logic::Term
  args.each { |k, v| result[k.to_s] = v }
  result
end

# Helper to create typed array for list items
private def items(*args : SYMBOL::Logic::Term) : Array(SYMBOL::Logic::Term)
  result = [] of SYMBOL::Logic::Term
  args.each { |a| result << a }
  result
end

describe SYMBOL::Logic do
  describe ".unify" do
    it "unifies identical atoms" do
      a1 = SYMBOL::Logic::Atom.new("hello")
      a2 = SYMBOL::Logic::Atom.new("hello")
      sub = SYMBOL::Logic.unify(a1, a2)
      sub.should_not be_nil
      sub.not_nil!.empty?.should be_true
    end

    it "fails to unify different atoms" do
      a1 = SYMBOL::Logic::Atom.new("hello")
      a2 = SYMBOL::Logic::Atom.new("world")
      sub = SYMBOL::Logic.unify(a1, a2)
      sub.should be_nil
    end

    it "unifies variable with atom" do
      v = SYMBOL::Logic::Var.new("X")
      a = SYMBOL::Logic::Atom.new("hello")
      sub = SYMBOL::Logic.unify(v, a)
      sub.should_not be_nil
      sub.not_nil!["X"].should eq a
    end

    it "unifies atom with variable" do
      a = SYMBOL::Logic::Atom.new("hello")
      v = SYMBOL::Logic::Var.new("X")
      sub = SYMBOL::Logic.unify(a, v)
      sub.should_not be_nil
      sub.not_nil!["X"].should eq a
    end

    it "unifies two variables" do
      v1 = SYMBOL::Logic::Var.new("X")
      v2 = SYMBOL::Logic::Var.new("Y")
      sub = SYMBOL::Logic.unify(v1, v2)
      sub.should_not be_nil
      # One should be bound to the other
      (sub.not_nil!["X"]? || sub.not_nil!["Y"]?).should_not be_nil
    end

    it "unifies structs with same tag" do
      s1 = SYMBOL::Logic::Struct.new("person", attrs(name: SYMBOL::Logic::Atom.new("Alice")))
      s2 = SYMBOL::Logic::Struct.new("person", attrs(name: SYMBOL::Logic::Var.new("N")))
      sub = SYMBOL::Logic.unify(s1, s2)
      sub.should_not be_nil
      sub.not_nil!["N"].should eq SYMBOL::Logic::Atom.new("Alice")
    end

    it "fails to unify structs with different tags" do
      s1 = SYMBOL::Logic::Struct.new("person")
      s2 = SYMBOL::Logic::Struct.new("animal")
      sub = SYMBOL::Logic.unify(s1, s2)
      sub.should be_nil
    end

    it "unifies lists of same length" do
      l1 = SYMBOL::Logic::TermList.new(items(
        SYMBOL::Logic::Atom.new(1.0),
        SYMBOL::Logic::Var.new("X"),
      ))
      l2 = SYMBOL::Logic::TermList.new(items(
        SYMBOL::Logic::Atom.new(1.0),
        SYMBOL::Logic::Atom.new(2.0),
      ))
      sub = SYMBOL::Logic.unify(l1, l2)
      sub.should_not be_nil
      sub.not_nil!["X"].should eq SYMBOL::Logic::Atom.new(2.0)
    end

    it "fails to unify lists of different length" do
      l1 = SYMBOL::Logic::TermList.new(items(SYMBOL::Logic::Atom.new(1.0)))
      l2 = SYMBOL::Logic::TermList.new(items(
        SYMBOL::Logic::Atom.new(1.0),
        SYMBOL::Logic::Atom.new(2.0),
      ))
      sub = SYMBOL::Logic.unify(l1, l2)
      sub.should be_nil
    end

    it "performs occurs check" do
      v = SYMBOL::Logic::Var.new("X")
      l = SYMBOL::Logic::TermList.new(items(v))
      sub = SYMBOL::Logic.unify(v, l)
      sub.should be_nil # X cannot contain itself
    end

    it "chains substitutions" do
      v1 = SYMBOL::Logic::Var.new("X")
      v2 = SYMBOL::Logic::Var.new("Y")
      a = SYMBOL::Logic::Atom.new("value")

      sub1 = SYMBOL::Logic.unify(v1, v2)
      sub1.should_not be_nil

      sub2 = SYMBOL::Logic.unify(v2, a, sub1.not_nil!)
      sub2.should_not be_nil

      # Walking X should give us "value"
      result = SYMBOL::Logic.walk(v1, sub2.not_nil!)
      result.should eq a
    end
  end

  describe ".walk" do
    it "returns atom unchanged" do
      a = SYMBOL::Logic::Atom.new("test")
      sub = SYMBOL::Logic::Substitution.new
      result = SYMBOL::Logic.walk(a, sub)
      result.should eq a
    end

    it "returns unbound variable unchanged" do
      v = SYMBOL::Logic::Var.new("X")
      sub = SYMBOL::Logic::Substitution.new
      result = SYMBOL::Logic.walk(v, sub)
      result.should eq v
    end

    it "resolves bound variable" do
      v = SYMBOL::Logic::Var.new("X")
      a = SYMBOL::Logic::Atom.new("test")
      sub = SYMBOL::Logic::Substitution.new
      sub["X"] = a
      result = SYMBOL::Logic.walk(v, sub)
      result.should eq a
    end

    it "resolves chain of variables" do
      vx = SYMBOL::Logic::Var.new("X")
      vy = SYMBOL::Logic::Var.new("Y")
      a = SYMBOL::Logic::Atom.new("final")

      sub = SYMBOL::Logic::Substitution.new
      sub["X"] = vy
      sub["Y"] = a

      result = SYMBOL::Logic.walk(vx, sub)
      result.should eq a
    end
  end

  describe SYMBOL::Logic::ForwardEngine do
    it "stores asserted facts" do
      engine = SYMBOL::Logic::ForwardEngine.new
      fact = SYMBOL::Logic::Struct.new("person", attrs(name: SYMBOL::Logic::Atom.new("Alice")))
      engine.assert(fact)
      engine.facts.size.should eq 1
    end

    it "prevents duplicate facts" do
      engine = SYMBOL::Logic::ForwardEngine.new
      fact = SYMBOL::Logic::Struct.new("person", attrs(name: SYMBOL::Logic::Atom.new("Alice")))
      engine.assert(fact).should be_true
      engine.assert(fact).should be_false
      engine.facts.size.should eq 1
    end

    it "queries matching facts" do
      engine = SYMBOL::Logic::ForwardEngine.new
      engine.assert(SYMBOL::Logic::Struct.new("person", attrs(
        name: SYMBOL::Logic::Atom.new("Alice"),
        age: SYMBOL::Logic::Atom.new(30.0),
      )))
      engine.assert(SYMBOL::Logic::Struct.new("person", attrs(
        name: SYMBOL::Logic::Atom.new("Bob"),
        age: SYMBOL::Logic::Atom.new(25.0),
      )))

      pattern = SYMBOL::Logic::Struct.new("person", attrs(name: SYMBOL::Logic::Var.new("N")))
      results = engine.query(pattern)
      results.size.should eq 2
    end

    it "fires rules on new facts" do
      engine = SYMBOL::Logic::ForwardEngine.new

      # Rule: person with any name is adult
      pattern = SYMBOL::Logic::Struct.new("person", attrs(name: SYMBOL::Logic::Var.new("N")))
      conclusion = SYMBOL::Logic::Struct.new("adult", attrs(name: SYMBOL::Logic::Var.new("N")))
      rule = SYMBOL::Logic::Rule.new("adult_rule", pattern, conclusion)
      engine.add_rule(rule)

      # Assert a person
      engine.assert(SYMBOL::Logic::Struct.new("person", attrs(name: SYMBOL::Logic::Atom.new("Alice"))))
      engine.propagate

      # Should have derived adult fact
      adult_pattern = SYMBOL::Logic::Struct.new("adult", attrs(name: SYMBOL::Logic::Var.new("X")))
      results = engine.query(adult_pattern)
      results.size.should eq 1
    end
  end

  describe SYMBOL::Logic::BackwardEngine do
    it "answers simple queries from facts" do
      engine = SYMBOL::Logic::BackwardEngine.new
      engine.add_fact(SYMBOL::Logic::Struct.new("parent", attrs(
        child: SYMBOL::Logic::Atom.new("Alice"),
        parent: SYMBOL::Logic::Atom.new("Bob"),
      )))

      query = SYMBOL::Logic::Struct.new("parent", attrs(
        child: SYMBOL::Logic::Atom.new("Alice"),
        parent: SYMBOL::Logic::Var.new("P"),
      ))
      results = engine.query(query)
      results.size.should eq 1
      results[0]["P"].should eq SYMBOL::Logic::Atom.new("Bob")
    end

    it "answers queries using rules" do
      engine = SYMBOL::Logic::BackwardEngine.new

      # Facts
      engine.add_fact(SYMBOL::Logic::Struct.new("parent", attrs(
        child: SYMBOL::Logic::Atom.new("Alice"),
        parent: SYMBOL::Logic::Atom.new("Bob"),
      )))
      engine.add_fact(SYMBOL::Logic::Struct.new("parent", attrs(
        child: SYMBOL::Logic::Atom.new("Bob"),
        parent: SYMBOL::Logic::Atom.new("Carol"),
      )))

      # Rule: grandparent(X, Z) :- parent(X, Y), parent(Y, Z)
      head = SYMBOL::Logic::Struct.new("grandparent", attrs(
        child: SYMBOL::Logic::Var.new("X"),
        grandparent: SYMBOL::Logic::Var.new("Z"),
      ))
      body = [] of SYMBOL::Logic::Term
      body << SYMBOL::Logic::Struct.new("parent", attrs(
        child: SYMBOL::Logic::Var.new("X"),
        parent: SYMBOL::Logic::Var.new("Y"),
      ))
      body << SYMBOL::Logic::Struct.new("parent", attrs(
        child: SYMBOL::Logic::Var.new("Y"),
        parent: SYMBOL::Logic::Var.new("Z"),
      ))
      engine.add_rule(head, body)

      query = SYMBOL::Logic::Struct.new("grandparent", attrs(
        child: SYMBOL::Logic::Atom.new("Alice"),
        grandparent: SYMBOL::Logic::Var.new("G"),
      ))
      results = engine.query(query)
      results.size.should eq 1
      # Need to walk to fully resolve the variable chain
      g_binding = results[0]["G"]
      g_binding.should_not be_nil
      resolved = SYMBOL::Logic.walk(g_binding.not_nil!, results[0])
      resolved.should eq SYMBOL::Logic::Atom.new("Carol")
    end
  end
end
