require 'win32console'
require 'mongo'
require './lib/manager/state'
require './lib/setup'

$db = Mongo::Connection.new.db('test')
$scoll = $db['states']
$pcoll = $db['packages']

describe State do
  describe 'from_marc' do
    before(:each) do
      #reads in marc record
      @recs = []
      MARC::Reader.new('test/data/state_from_marc1.mrc').each {|rec| @recs << rec}
      type = :add
      date = Date.new(2010, 6, 1)
      @state = State.new.from_marc(@recs[0], date, type)
    end
    it "populates SSID" do
      @state[:ssid].should == 'sse0000394939'
    end
    it "populates date" do
      @state[:date].should == Date.new(2010, 6, 1)
    end
    it "populates packages" do
      @state[:packages].should == ['IEEE/IET Electronic Library (IEL) Proceedings By Volume']
    end
    it "populates marc" do
      @state[:marc]['fields'][0][1].should == 'sse0000394939'
    end
    it "populates type" do
      @state[:type].should == :add
    end
    it "populates working?" do
      @state[:working?].should == true
    end
  end

  describe 'from_db' do
    before(:each) do
      $scoll.remove
      @recs = []
      MARC::Reader.new('test/data/state_from_db.mrc').each {|rec| @recs << rec}
      date = Time.new(2010, 6, 1)
      @pre = State.new.from_marc(@recs[0], date, :add)
      @dbid = $scoll.insert(@pre)
      dbrec = $scoll.find('ssid' => 'sseb005507869').first
      @state = State.new.from_db(dbrec)
    end
    it "keeps track of BSON::ObjectID so that package can be updated in db" do
      @state.dbid.should == @dbid
    end
    it "populates SSID" do
      @state[:ssid].should == 'sseb005507869'
    end
    it "populates date" do
      @state[:date].should == Time.new(2010, 6, 1)
    end
    it "populates packages" do
      @state[:packages].should == ['Literary Reference Center']
    end
    it "populates marc" do
      @state[:marc].class.should == MARC::Record
    end
    it "populates type" do
      @state[:type].should == :add
    end
    it "populates working?" do
      @state[:working?].should == true
    end
  end

  describe "save" do
    it "saves a State back to the db (updates db)" do
      $scoll.remove
      @recs = []
      MARC::Reader.new('test/data/state_from_db.mrc').each {|rec| @recs << rec}
      date = Time.new(2010, 6, 1)
      @pre = State.new.from_marc(@recs[0], date, :add)
      @dbid = $scoll.insert(@pre)
      dbrec = $scoll.find('ssid' => 'sseb005507869').first
      @state = State.new.from_db(dbrec)

      # change name in db package and save
      @state[:type] = :delete
      @state.save
      # retrieve package from db by new name.
      dbrec = $scoll.find('ssid' => 'sseb005507869').first
      dbrec['type'].should == :delete
    end
  end

  describe "find_in_db" do
    before(:each) do
      @recs = []
      MARC::Reader.new('test/data/state_from_db.mrc').each {|rec| @recs << rec}
      date = Time.new(2010, 6, 1)
      @pre = State.new.from_marc(@recs[0], date, :add)
      @dbid = $scoll.insert(@pre)
      date = Time.new(2010, 9, 1)
      @pre = State.new.from_marc(@recs[0], date, :add)
      @dbid = $scoll.insert(@pre)
      date = Time.new(2010, 8, 1)
      @pre = State.new.from_marc(@recs[0], date, :add)
      @dbid = $scoll.insert(@pre)

      @nrecs = []
      MARC::Reader.new('test/data/state_from_marc1.mrc').each {|rec| @nrecs << rec}
      date = Time.new(2010, 7, 1)
      @pre = State.new.from_marc(@nrecs[0], date, :add)
      @dbid = $scoll.insert(@pre)
      date = Time.new(2010, 8, 1)
      @pre = State.new.from_marc(@nrecs[0], date, :add)
      @dbid = $scoll.insert(@pre)
    end
    it "Retrieves array of all matching state records" do      
      MARC::Reader.new('test/data/state_from_db.mrc').each {|rec| @recs << rec}
      date = Time.new(2010, 6, 1)
      @pre = State.new.from_marc(@recs[0], date, :add)
      @pre.find_in_db.count.should == 3
    end
    it "Retrieves most recent matching state record first" do
      MARC::Reader.new('test/data/state_from_db.mrc').each {|rec| @recs << rec}
      date = Time.new(2010, 9, 1)
      @pre = State.new.from_marc(@recs[0], date, :add)
      @pre.find_in_db.first['date'].should == date
    end

    after(:each) do
      $scoll.remove
    end
  end

  describe "in_db?" do
    before(:each) do
      @recs = []
      MARC::Reader.new('test/data/state_from_db.mrc').each {|rec| @recs << rec}
      date = Time.new(2010, 6, 1)
      @pre = State.new.from_marc(@recs[0], date, :add)
      @dbid = $scoll.insert(@pre)
      date = Time.new(2010, 9, 1)
      @pre = State.new.from_marc(@recs[0], date, :add)
      @dbid = $scoll.insert(@pre)
      date = Time.new(2010, 8, 1)
      @pre = State.new.from_marc(@recs[0], date, :add)
      @dbid = $scoll.insert(@pre)

      @nrecs = []
      MARC::Reader.new('test/data/state_from_marc1.mrc').each {|rec| @nrecs << rec}
      date = Time.new(2010, 7, 1)
      @pre = State.new.from_marc(@nrecs[0], date, :add)
      @dbid = $scoll.insert(@pre)
      date = Time.new(2010, 8, 1)
      @pre = State.new.from_marc(@nrecs[0], date, :add)
      @dbid = $scoll.insert(@pre)
    end
    it "Returns false if matching States not found" do
      @frecs = []
      MARC::Reader.new('test/data/add_test_24.mrc').each {|rec| @frecs << rec}
      date = Time.new(2010, 9, 1)
      @pre = State.new.from_marc(@frecs[15], date, :add)
      @pre.in_db?.should == false
    end
    it "Returns true if matching States found" do
      @grecs = []
      MARC::Reader.new('test/data/state_from_db.mrc').each {|rec| @grecs << rec}
      date = Time.new(2010, 12, 1)
      @pre = State.new.from_marc(@grecs[0], date, :add)
      @pre.in_db?.should == true
    end

    after(:each) do
      $scoll.remove
    end
  end

  describe "libs" do
    it "returns libraries holding one package" do
      $scoll.remove
      $pcoll.remove
      @e1 = {"name"=>"Literary Reference Center", "aalload"=>"7/1/2010", "aalqual"=>"nil",
        "aaldupe"=>nil, "aalpending"=>nil, "hsl"=>"9/1/2010", "law"=>"d8/1/2010"}
      pkg = Package.new.from_csv(@e1)
      $pcoll.insert(pkg)

      @precs = []
      MARC::Reader.new('test/data/state_from_db.mrc').each {|rec| @precs << rec}
      date = Time.new(2010, 12, 1)
      @rec = State.new.from_marc(@precs[0], date, :add)

      @rec.libs.should == [:aalload, :hsl]
    end
    it "returns libraries holding more than one package 1" do
      $scoll.remove
      $pcoll.remove
      @e1 = {"name"=>"Literary Reference Center", "aalload"=>"7/1/2010", "aalqual"=>"nil",
        "aaldupe"=>nil, "aalpending"=>nil, "hsl"=>"9/1/2010", "law"=>"d8/1/2010"}
      @e2 = {"name"=>"Black Drama", "aalload"=>"d7/1/2010", "aalqual"=>"7/1/2010",
        "aaldupe"=>nil, "aalpending"=>nil, "hsl"=>"10/1/2010", "law"=>"8/1/2010"}
      pkg1 = Package.new.from_csv(@e1)
      $pcoll.insert(pkg1)
      pkg2 = Package.new.from_csv(@e2)
      $pcoll.insert(pkg2)

      @qrecs = []
      MARC::Reader.new('test/data/state_libs_2_pkgs.mrc').each {|rec| @qrecs << rec}
      date = Time.new(2010, 12, 1)
      @rec = State.new.from_marc(@qrecs[0], date, :add)

      @rec.libs.should == [:aalload, :aalqual, :hsl, :law]
    end
    it "returns libraries holding more than one package 2" do
      $scoll.remove
      $pcoll.remove
      @e1 = {"name"=>"Literary Reference Center", "aalload"=>"d7/1/2010", "aalqual"=>"nil",
        "aaldupe"=>nil, "aalpending"=>nil, "hsl"=>"9/1/2010", "law"=>"d8/1/2010"}
      @e2 = {"name"=>"Black Drama", "aalload"=>"d7/1/2010", "aalqual"=>"7/1/2010",
        "aaldupe"=>nil, "aalpending"=>nil, "hsl"=>"10/1/2010", "law"=>"8/1/2010"}
      pkg1 = Package.new.from_csv(@e1)
      $pcoll.insert(pkg1)
      pkg2 = Package.new.from_csv(@e2)
      $pcoll.insert(pkg2)

      @rrecs = []
      MARC::Reader.new('test/data/state_libs_2_pkgs.mrc').each {|rec| @rrecs << rec}
      date = Time.new(2010, 12, 1)
      @rec = State.new.from_marc(@rrecs[0], date, :add)

      @rec.libs.should == [:aalqual, :hsl, :law]
    end
  end
end

