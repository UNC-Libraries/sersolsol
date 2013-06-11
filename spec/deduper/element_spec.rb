require './lib/deduper'

describe Element do

  describe "initialize" do

  it "sets column (col) to data array index" do
    a = %w(a b c)
    e = Element.new(a.index(a[0]), a[0])
    e.col.should == 0
  end

    it "sets name to header value" do
       a = %w(a b c)
    e = Element.new(a.index(a[0]), a[0])
    e.name.should == "a"
    end
  end

  describe "displaynum" do

    it "returns number (string) to be displayed in menus" do
        a = %w(a b c)
    e = Element.new(a.index(a[0]), a[0])
    e.displaynum.should == "1"
    end
    
  end
end

