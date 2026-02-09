require "./spec_helper"

describe SYMBOL do
  it "has a version" do
    SYMBOL::VERSION.should eq("0.1.0")
  end
end
