require 'lib/deduper'

describe Compound do
  before(:each) do
    $materials = []
  end

  describe "initialize" do
    before(:each) do
      @e1 = Element.new(0, "first")
      @e2 = Element.new(1, "second")
    end

    it "sends Compound to $materials" do
      Compound.new(@e1, @e2)
      $materials.size.should == 3
    end

    describe "when components are elements" do
      it "sets component1 to first component" do
        d = @e1
        c = Compound.new(@e1, @e2)
        c.component1.should == d
      end

      it "sets component2 to second component" do
        d = @e2
        c = Compound.new(@e1, @e2)
        c.component2.should == d
      end
    end

    describe "when component1 is a Compound" do
      before(:each) do
        @c = Compound.new(@e1, @e2)
        @e3 = Element.new(2, "third")
      end

      it "sets component1 to first component" do
        d = @c
        cc = Compound.new(@c, @e3)
        cc.component1.should == d
      end

      it "sets name to a concatenated string" do
        cc = Compound.new(@c, @e3)
        cc.name.should == "first + second + third"
      end

      it "sets col to an array of all involved columns" do
        cc = Compound.new(@c, @e3)
        cc.col.should == [0, 1, 2]
      end

      it "sets displaynum" do
        cc = Compound.new(@c, @e3)
        cc.displaynum.should == "5"
      end
    end
  end
end
