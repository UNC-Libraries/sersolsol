require 'win32console'
require 'mongo'

require './lib/manager/package'
require './lib/setup'

describe Package do
  before(:each) do
   $db = Mongo::Connection.new.db('test')
   $pcoll = $db['packages']
   $pcoll.remove
  end

  describe "METHODS:" do
    describe "from_csv(row)" do
      before(:each) do
        @e1 = {"name"=>"p1",
          "aalload"=>"d7/1/2010",
          "aalqual"=>"6/1/2010",
          "aaldupe"=>nil,
          "aalpending"=>nil,
          "hsl"=>nil,
          "law"=>nil}

        @e2 = {"name"=>"p1;;;p2;;;p3",
          "aalload"=>"7/1/2010",
          "aalqual"=>"d6/1/2010",
          "aaldupe"=>nil,
          "aalpending"=>nil,
          "hsl"=>nil,
          "law"=>nil}

        @e3 = {"name"=>"p1;;;p2;;;p3",
          "aalload"=>nil,
          "aalqual"=>"d6/1/2010",
          "aaldupe"=>nil,
          "aalpending"=>nil,
          "hsl"=>"6/1/2010",
          "law"=>nil}

        @e4 = {"name"=>"p1;;;p2;;;p3",
          "aalload"=>nil,
          "aalqual"=>"6/1/2010",
          "aaldupe"=>nil,
          "aalpending"=>nil,
          "hsl"=>nil,
          "law"=>nil}

        @e5 = {"name"=>"p1;;;p2;;;p3",
          "aalload"=>nil,
          "aalqual"=>nil,
          "aaldupe"=>nil,
          "aalpending"=>"6/1/2010",
          "hsl"=>nil,
          "law"=>nil}

        @e6 = {"name"=>"p1;;;p2;;;p3",
          "aalload"=>nil,
          "aalqual"=>nil,
          "aaldupe"=>"6/1/2010",
          "aalpending"=>nil,
          "hsl"=>nil,
          "law"=>nil}
      end

      it "maps one name" do
        pkg = Package.new.from_csv(@e1)
        pkg[:names].should == ['p1']
      end
      it "maps more than one name" do
        pkg = Package.new.from_csv(@e2)
        pkg[:names].should == ['p1', 'p2', 'p3']
      end
      it "maps claims" do
        pkg = Package.new.from_csv(@e2)
        pkg[:claims].should == [{:lib => :aalload, :date => '7/1/2010', :type => :in},
          {:lib => :aalqual, :date => '6/1/2010', :type => :out}]
      end
      describe "sets status" do
        it "load (aalload)" do
          pkg = Package.new.from_csv(@e2)
          pkg[:status].should == :load
        end
        it "load (hsl)" do
          pkg = Package.new.from_csv(@e3)
          pkg[:status].should == :load
        end
        it "no load withdrawn" do
          pkg = Package.new.from_csv(@e1)
          pkg[:status].should == :no_load_withdrawn
        end
        it "no load quality" do
          pkg = Package.new.from_csv(@e4)
          pkg[:status].should == :no_load_quality
        end
        it "no load pending" do
          pkg = Package.new.from_csv(@e5)
          pkg[:status].should == :no_load_pending
        end
        it "no load duplicate" do
          pkg = Package.new.from_csv(@e6)
          pkg[:status].should == :no_load_duplicate
        end
      end
    end
    describe "from_db(bh)" do
      before(:each) do
        # sets up db
        $pcoll.remove({})
        # creates csv package to send to db and inserts it in db, retaining its
        # BSON::ObjectID
        @e1 = {"name"=>"p1", "aalload"=>"d7/1/2010", "aalqual"=>"6/1/2010",
          "aaldupe"=>nil, "aalpending"=>nil, "hsl"=>nil, "law"=>nil}
        @csvp = Package.new.from_csv(@e1)
        @bid = $pcoll.insert(@csvp)
      end
      it "populates Package instance with data from MongoDB document" do
        # retrieves package document from db and creates new db Package from it
        doc = $pcoll.find('names' => 'p1').first
        dbp = Package.new.from_db(doc)
        # sets up counter to keep track of matches
        @count = 0
        @count += 1 if dbp[:names].join == @csvp[:names].join
        @count += 1 if dbp[:status].to_s == @csvp[:status].to_s
        @count += 1 if dbp[:claims] == @csvp[:claims]
        @count.should == 3
      end
      it "keeps track of BSON::ObjectID so that package can be updated in db" do
        doc = $pcoll.find('names' => 'p1').first
        dbp = Package.new.from_db(doc)
        dbp.dbid.should == @bid
      end
    end
    describe "save" do
      it "saves a Package back to the db (updates db)" do
        # creates csv package to send to db
        @e1 = {"name"=>"p1", "aalload"=>"d7/1/2010", "aalqual"=>"6/1/2010",
          "aaldupe"=>nil, "aalpending"=>nil, "hsl"=>nil, "law"=>nil}
        @csvp = Package.new.from_csv(@e1)
        # insert csv package into db, keep its BSON::ObjectID
        @bid = $pcoll.insert(@csvp)
        # create db package from retrieved package just inserted
        doc = $pcoll.find('names' => 'p1').first
        dbp = Package.new.from_db(doc)
        # change name in db package and save
        dbp[:names] = ['changed']
        dbp.save
        # retrieve package from db by new name.
        $pcoll.find('names' => 'changed').count.should == 1
      end
    end
    describe "find_in_db" do
      it "if there is one match in db" do
        # creates csv package to send to db
        @e1 = {"name"=>"p1", "aalload"=>"d7/1/2010", "aalqual"=>"6/1/2010",
          "aaldupe"=>nil, "aalpending"=>nil, "hsl"=>nil, "law"=>nil}
        @csvp = Package.new.from_csv(@e1)
        # insert csv package into db, keep its BSON::ObjectID
        @bid = $pcoll.insert(@csvp)
        results = @csvp.find_in_db
        results[0]['_id'].should == @bid
      end
      it "if there is more than one match in db" do
        # creates csv packages to send to db
        @e1 = {"name"=>"p1", "aalload"=>"d7/1/2010", "aalqual"=>"6/1/2010",
          "aaldupe"=>nil, "aalpending"=>nil, "hsl"=>nil, "law"=>nil}
        @e2 = {"name"=>"p1", "aalload"=>"d7/1/2010", "aalqual"=>"6/1/2010",
          "aaldupe"=>nil, "aalpending"=>nil, "hsl"=>nil, "law"=>nil}
        @csvp1 = Package.new.from_csv(@e1)
        @csvp2 = Package.new.from_csv(@e2)
        # insert csv package into db, keep its BSON::ObjectID
        @bid1 = $pcoll.insert(@csvp1)
        @bid2 = $pcoll.insert(@csvp2)
        @e1 = {"name"=>"p1", "aalload"=>"d7/1/2010", "aalqual"=>"6/1/2010",
          "aaldupe"=>nil, "aalpending"=>nil, "hsl"=>nil, "law"=>nil}
        @csvp3 = Package.new.from_csv(@e1)
        results = @csvp3.find_in_db
        @ids = []
        results.each {|r| @ids << r['_id']}
        @ids.should == [@bid1, @bid2]
      end
    end
    describe "in_db?" do
      it "if there is not a match in db, returns false" do
        @e1 = {"name"=>"p1", "aalload"=>"d7/1/2010", "aalqual"=>"6/1/2010",
          "aaldupe"=>nil, "aalpending"=>nil, "hsl"=>nil, "law"=>nil}
        @csvp1 = Package.new.from_csv(@e1)
        @csvp1.in_db?.should == false
      end
      it "if there is a match in db, returns true" do
        #creates csv Package and adds it to db
        @e1 = {"name"=>"p1", "aalload"=>"d7/1/2010", "aalqual"=>"6/1/2010",
          "aaldupe"=>nil, "aalpending"=>nil, "hsl"=>nil, "law"=>nil}
        @csvp1 = Package.new.from_csv(@e1)
        $pcoll.insert(@csvp1)
        #creates another csv Package with matching name and looks for it in db
        @e2 = {"name"=>"p1;;;p2", "aalload"=>"d7/1/2010", "aalqual"=>"6/1/2010",
          "aaldupe"=>nil, "aalpending"=>nil, "hsl"=>nil, "law"=>nil}
        @csvp2 = Package.new.from_csv(@e2)
        @csvp2.in_db?.should == true
      end
    end
    describe "active_libs" do
      it "one date per lib" do
        e1 = {"name"=>"p1", "aalload"=>"7/1/2010", "aalqual"=>"d7/1/2010",
          "aaldupe"=>nil, "aalpending"=>nil, "hsl"=>"9/1/2010", "law"=>"d6/1/2010"}
        pkg = Package.new.from_csv(e1)
        $pcoll.insert(pkg)
        pkg.active_libs.should == [:aalload, :hsl]  
      end
      it "lib in and out" do
        e1 = {"name"=>"p1", "aalload"=>"7/1/2010", "aalqual"=>"d7/1/2010",
          "aaldupe"=>nil, "aalpending"=>nil, "hsl"=>"9/1/2010", "hsl"=>"d10/1/2010",
          "law"=>"d6/1/2010"}
        pkg = Package.new.from_csv(e1)
        $pcoll.insert(pkg)
        pkg.active_libs.should == [:aalload]
      end
    end
  end
end

