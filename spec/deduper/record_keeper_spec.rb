# To change this template, choose Tools | Templates
# and open the template in the editor.

require './lib/deduper'

describe RecordKeeper do

  describe 'initialize' do
   it 'creates an element for each header and adds the element to materials' do
     a = RecordKeeper.new(["b", "c", "d"])
     a.materials[0].class.should == Element
   end
  end

  describe 'lookup_material_by_display_number' do
    it 'retrieves the material associated with a display number' do
      a = RecordKeeper.new(["b", "c", "d"])
      a.lookup_material_by_display_number(3).name.should == "d"
    end
  end
end

