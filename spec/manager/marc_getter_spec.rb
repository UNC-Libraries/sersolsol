require 'win32console'
require './lib/manager/marc_getter'
require './lib/setup'


describe MarcGetter do
  describe 'populate_state_hash' do
    before :each do
      @a = State.new; @a[:date] = '6'; @a[:type] = :add
      @d = State.new; @d[:date] = '7'; @d[:type] = :change
      @c = State.new; @c[:date] = '7'; @c[:type] = :add
      @b = State.new; @b[:date] = '6'; @b[:type] = :add
      @e = State.new; @e[:date] = '7'; @e[:type] = :change
      @states = [@a, @d, @c, @b, @e]
    end
    it "create state hash" do
      mg = MarcGetter.new(@states)
      sh = mg.populate_state_hash(@states)
      sh.should == {'6add.mrc' => [{:date => '6', :type => :add}, {:date => '6', :type => :add}],
        '7change.mrc' => [{:date => '7', :type => :change}, {:date => '7', :type => :change}],
        '7add.mrc' => [{:date => '7', :type => :add}]}
    end    
  end
  describe 'construct_path' do
    before :each do
      @a = State.new; @a[:date] = '6'; @a[:type] = :add
      @states = [@a]
    end
    it "builds path from filename" do
      mg = MarcGetter.new(@states)
      path = mg.construct_path('20100901add.mrc')
      path.should == 'data/ssmrc/orig/2010/20100901add.mrc'
    end
  end
end


