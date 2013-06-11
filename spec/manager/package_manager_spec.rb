require 'win32console'
require 'mongo'
require './lib/manager/package_manager'


describe PackageManager do
  before(:each) do
    $db = Mongo::Connection.new.db('test')
    $pcoll = $db['packages']
    $pcoll.remove
  end

  describe 'When a csv package does not exist in the db' do
    it 'Add it to the db' do
      PackageManager.new('test/data/pkg_list_claim_change.csv').execute
      $pcoll.find.count.should == 2
    end
  end

  describe "When a csv package exists once in db" do
    describe "Compare and update" do
      it "Updates db names to match csv" do
        # creates csv package to send to db
        @e1 = {"name"=>"p1", "aalload"=>"d7/1/2010", "aalqual"=>"6/1/2010",
          "aaldupe"=>nil, "aalpending"=>nil, "hsl"=>nil, "law"=>nil}
        @e2 = {"name"=>"p3;;;p4", "aalload"=>"d7/1/2010", "aalqual"=>"6/1/2010",
          "aaldupe"=>nil, "aalpending"=>nil, "hsl"=>nil, "law"=>nil}
        @e3 = {"name"=>"p18;;;p23", "aalload"=>"d7/1/2010", "aalqual"=>"6/1/2010",
          "aaldupe"=>nil, "aalpending"=>nil, "hsl"=>nil, "law"=>nil}
        @cp1 = Package.new.from_csv(@e1)
        @cp2 = Package.new.from_csv(@e2)
        @cp3 = Package.new.from_csv(@e3)
        # insert csv package into db, keep its BSON::ObjectID
        @bid1 = $pcoll.insert(@cp1)
        @bid2 = $pcoll.insert(@cp2)
        @bid3 = $pcoll.insert(@cp3)
        #runs PackageManager on csv with name changes
        PackageManager.new('test/data/pkg_list_name_change.csv').execute
        db1 = Package.new.from_db(@cp1.find_in_db[0])
        db2 = Package.new.from_db(@cp2.find_in_db[0])
        db3 = Package.new.from_db(@cp3.find_in_db[0])
        [db1[:names], db2[:names], db3[:names]].should == [['p1', 'p2'], ['p3'], ['p18', 'p23']]
      end
      it "Compares and updates status" do
        # creates csv package to send to db
        @e1 = {"name"=>"p1", "aalload"=>"d7/1/2010", "aalqual"=>"6/1/2010",
          "aaldupe"=>nil, "aalpending"=>nil, "hsl"=>nil, "law"=>nil}
        @e2 = {"name"=>"p3;;;p4", "aalload"=>"d7/1/2010", "aalqual"=>"6/1/2010",
          "aaldupe"=>nil, "aalpending"=>nil, "hsl"=>nil, "law"=>nil}
        @cp1 = Package.new.from_csv(@e1)
        @cp2 = Package.new.from_csv(@e2)
        # insert csv package into db, keep its BSON::ObjectID
        @bid1 = $pcoll.insert(@cp1)
        @bid2 = $pcoll.insert(@cp2)
        #runs PackageManager on csv with status changes
        PackageManager.new('test/data/pkg_list_name_change.csv').execute
        db1 = Package.new.from_db(@cp1.find_in_db[0])
        db2 = Package.new.from_db(@cp2.find_in_db[0])
        [db1[:status], db2[:status]].should == [:load, :no_load_duplicate]
      end
      it "Compares and updates claims" do
        # creates csv package to send to db
        @e1 = {"name"=>"p1", "aalload"=>nil, "aalqual"=>"6/1/2010",
          "aaldupe"=>nil, "aalpending"=>nil, "hsl"=>nil, "law"=>nil}
        @e2 = {"name"=>"p3;;;p4", "aalload"=>nil, "aalqual"=>nil,
          "aaldupe"=>"9/1/2010", "aalpending"=>nil, "hsl"=>nil, "law"=>nil}
        @cp1 = Package.new.from_csv(@e1)
        @cp2 = Package.new.from_csv(@e2)
        # insert csv package into db, keep its BSON::ObjectID
        @bid1 = $pcoll.insert(@cp1)
        @bid2 = $pcoll.insert(@cp2)
        #runs PackageManager on csv with status changes
        PackageManager.new('test/data/pkg_list_claim_change.csv').execute
        db1 = Package.new.from_db(@cp1.find_in_db[0])
        db2 = Package.new.from_db(@cp2.find_in_db[0])
        [db1[:claims].count, db2[:claims].count].should == [3, 1]
      end
    end
  end

  describe "When a csv package exists more than once in db" do
    describe "If one db packages has more name matches" do
      it "uses the one with the most matches to do comparisons/updates" do
        @pm = PackageManager.new('test/data/pkg_list_multiple_found_more_init.csv').execute
        @pm = PackageManager.new('test/data/pkg_list_multiple_found_more_next.csv').execute
        ct = 0
        t = $pcoll.find({'claims.date' => '9/9/1999'}).first
        ct += 1 if t['claims'].count == 2
        @maalload = 0
        t['claims'].each {|c| @maalload += 1 if c.has_key?('aalload')}
        ct += 1 if @maalload == 0
        ct.should == 2
      end
      it "logs message" do
        @pm = PackageManager.new('test/data/pkg_list_multiple_found_more_init.csv').execute
        @pm = PackageManager.new('test/data/pkg_list_multiple_found_more_next.csv').execute
        msg = "(Multiple pkg db matches. Updated one with most names in common.)"
        @pm.log[:warning][1].to_s.include?(msg).should == true
      end
      after(:each) do
        $pcoll.remove
      end
    end
    describe "If db packages have equal number of name matches" do
      it "logs message" do
        $pcoll.remove
        @pm = PackageManager.new('test/data/pkg_list_multiple_found_eql_init.csv').execute
        @pm = PackageManager.new('test/data/pkg_list_multiple_found_eql_next.csv').execute
        msg = "(Could not tell which pkg db to update.)"
        @pm.log[:warning][1].to_s.include?(msg).should == true
      end
    end
  end
end
