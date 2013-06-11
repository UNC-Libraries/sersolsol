require './lib/setup'
require 'csv'

# This class is initialized with the path to a csv file of package data.
# It updates the MongoDB package collection so that it reflects changes made
# in the csv.
class PackageManager < Command
  attr_reader :log
  def initialize(package_data)
    @csv = CSV.read(package_data, :headers => true)
    @log = {:new => ['New packages created', []],
      :name => ['Packages with names updated', []],
      :status => ['Packages with status updated', []],
      :claim => ['Packages with claims updated', []],
      :nothing => ['Packages with no changes', []],
      :warning => ['Packages with warnings', []]}
  end

=begin rdoc
* creates an array of hashed rows from csv, and for each of them:
** creates a Package object
** looks for db Package(s) document with matching name(s)
*** if none are found, saves csv Package to db.
*** if one is found
**** compare names and add any new csv names to db
**** compare claims and add any new csv claims to db
**** compare status and update db if necessary
*** if more than one is found
**** compare number of matching names in each found db package
***** if equal
****** write message to log and skip to next row
***** if unequal
****** write message to log
****** choose db package with most matching names and treat it as the sole match
=end
  def execute
    # create an array of hashed rows from csv
    @rows = []
    @csv.each do |row|
      temp = row.to_hash
      @rows << temp
    end

    @rows.each do |row|
      # create a Package object from csv row
      @cp = Package.new.from_csv(row)
      #check db for a matching package
      @results = @cp.find_in_db
      #if exists, do comparisons
      if @results.count > 0
        if @results.count == 1
          @dbp = Package.new.from_db(@results[0])
          checks(@cp, @dbp)
          
        else
          @ns = []; @results.each {|pkg| @ns << pkg['names']}
          @winner = ['nothing', 0]
          @ncompare = {}
          @results.each do |dbp|
            pkg = Package.new.from_db(dbp)
            int = pkg[:names] & @cp[:names]
            @ncompare[pkg] = int.count
          end

          @ncompare.each_pair do |pkg, ct|
            if ct > @winner[1]
              @winner = [pkg, ct]
            elsif ct == @winner[1]
              @winner = ["tie", ct]
            end
          end

          if @winner[0] == 'tie'
            msg = @cp[:names]
            msg << "(Could not tell which pkg db to update.)"
            @log[:warning][1] << msg.join(', ')
          elsif @winner[0].instance_of?(Package)
            @dbp = @winner[0]
            checks(@cp, @dbp)
            msg = @cp[:names]
            msg << "(Multiple pkg db matches. Updated one with most names in common.)"
            @log[:warning][1] << msg.join(', ')
            @dbp.save
          end
          
        end
        #if not exists, create new
      else
        $pcoll.insert(@cp)
        @log[:new][1] << @cp[:names].join(', ')
      end
    end
    return self
  end

  def report_full
    @log.each_pair do |k, v|
      puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
      puts "#{v[1].count} #{v[0].upcase}"
      puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
      v[1].each {|e| puts e}
    end
  end

  def report_summary
    @log.each_pair do |k, v|
      puts "#{v[1].count}\t#{v[0]}"
    end
    if @log[:warning][1].count > 0
    puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
    puts "WARNINGS"
    puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
    w = @log[:warning]
    w[1].each {|e| puts e}
    end
  end

  private


  def checks(cp, dbp)
    count = 0
    if dbp[:names] != cp[:names]
      dbp[:names] = cp[:names]
      @log[:name][1] << cp[:names].join(', ')
      count += 1
    end

    if dbp[:status] != cp[:status]
      dbp[:status] = cp[:status]
      @log[:status][1] << cp[:names].join(', ')
      count += 1
    end

    cp[:claims].each do |c|
      if dbp[:claims].include?(c) == false
        dbp[:claims] << c
        @log[:claim] << cp[:names].join(', ')
        count += 1
      end
    end
    
    if count > 0
      dbp.save
    else
      @log[:nothing][1] << cp[:names].join(', ')
    end
  end
end