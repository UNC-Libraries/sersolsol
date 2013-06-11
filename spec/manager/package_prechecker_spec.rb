require 'win32console'
require 'mongo'
require './lib/manager/package_prechecker'

describe PackagePrechecker do
  before(:each) do
    $db = Mongo::Connection.new.db('test')
    $pcoll = $db['packages']
    init = PackageManager.new('test/data/pkg_list.csv').execute
    @pre = PackagePrechecker.new('test/data/package_prechecker_test.mrc').execute
    # new
    # $xHealth Source: Doctor's Edition
    # $xSpringer
    # $xTesttttting
    #
    # existing
    # $xMATHnetBASE
    # $xBlack Thought and Culture
    # $xBlack Drama (Second Edition)
    # $xComputer Database
  end

  describe "Logs numbers of new, ambiguous, and existing package names in file" do
    it "Counts new packages" do
      @pre.log[:new][1].count.should == 3
    end
    it "Counts existing packages" do
      @pre.log[:existing][1].count.should == 4
    end
  end
end