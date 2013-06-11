class RecordKeeper
  attr_accessor :materials, :comparisons
  def initialize(header_row)
    @materials = []
    header_row.each do |name|
      number = header_row.index(name)
      e = Element.new(number, name)
      @materials << e
    end
    @comparisons = []
  end

#tested in tests/display_tests.rb
def list_comparisons
  self.comparisons.each {|c| puts c.display}
end

def list_materials
  puts "\n\nEXISTING ELEMENTS:"
  self.materials.each {|m| puts "#{m.displaynum}.  #{m.name}"}
end

def lookup_material_by_display_number(n)
  the_one = self.materials.select {|m| m.displaynum == n}
  return the_one[0]
end
end
