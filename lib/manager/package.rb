#require './lib/manager/command'

# The liason between package data in the csv file and in the db.
# Allows methods to be associated with packages, which can be read
# from and written to the db.
class Package < Hash
 
  attr_accessor :dbid
  # Create an instance of the class. Instance variables are set
  # by calling from_csv or from_db immediately after instantiation.
  #    pkg_from_db = Package.new.from_db(bh)
  #    pkg_from_csv = Package.new.from_csv(row)
  def initialize
  end

  # Returns an instance of Package populated with data from a csv row.
  # *Arguments*
  # [row] Expects the result of CSV::Row.to_hash
  def from_csv(row)
    #p row
    self[:names] = row['name'].split(';;;')
    row.delete('name')

    self[:claims] = []
    row.each_pair do |k, v|
      if v == nil
        next
      elsif v =~ /^\d/
        self[:claims] << {:lib => k.to_sym, :date => v, :type => :in}
      elsif v =~ /^d/
        self[:claims] << {:lib => k.to_sym, :date => v.gsub!(/^d/, ''), :type => :out}
      end
    end

    self[:status] = :unset
    @stati = []
    # p self
    self[:claims].each do |c|
      # p c
      if c[:lib] == :aalload or c[:lib] == :hsl or c[:lib] == :law
        if c[:type] == :in
          @stati << :load
        else
          @stati << :no_load_withdrawn
        end
      elsif c[:lib] == :aalqual
        @stati << :no_load_quality
      elsif c[:lib] == :aaldupe
        @stati << :no_load_duplicate
      elsif c[:lib] == :aalpending
        @stati << :no_load_pending
      end
    end
    @stati.uniq
    # puts "STATI: #{@stati}"
    if @stati.include?(:load)
      self[:status] = :load
    elsif @stati.include?(:no_load_withdrawn)
      self[:status] = :no_load_withdrawn
    else
      self[:status] = @stati[0].to_sym
    end
    # puts "STATUS: #{self[:status].inspect}"
    self
  end

  # Returns an instance of Package populated with data from MongoDB document.
  # Packages in MongoDB are edited by getting a package document from the db,
  # creating a new +Package+ from that db document, editing the +Package+ object,
  # and then using the save method.
  # *Arguments*
  # [bh] A BSON::OrderedHash
  # *Usage*
  # Assumes a MongoDB collection named +packages+.
  #    dbpkg = packages.find(:names => 'Springer Protocols').first
  #    pkg = Package.new.from_db(dbpkg)
  # (Make changes to the Package instance)
  #    pkg.save
  def from_db(bh) #BSON::OrderedHash    
    # store BSON::ObjectID from db object, simultaneously removing it from
    # retrieved hash
    @dbid = bh.delete('_id')
    # do a stupid jig to account for the fact that MongoDB transforms symbol
    # hash keys into strings. turn them back to symbols so they match csv
    # Packages
    bh.each_pair do |k, v|
      self[k.to_sym] = v
    end

    @new_claims = []
    self[:claims].each do |c|
      new_c = {}
      c.each_pair do |k, v|
        new_c[k.to_sym] = v
      end
      @new_claims << new_c
    end

    #self[:names] = bh['names']
    self[:claims] = @new_claims
    #self[:status] = bh['status']

    return self
  end

  # Saves the Package object back to the database, updating the existing
  # document.
  # *Usage* -- See #from_db
  def save
    $pcoll.update({'_id' => @dbid}, self)
  end

  # Returns array of MongoDB docs matching the Package object.
  # Lookup is by name.
  def find_in_db
    @results = []
    self[:names].each do |n|
      raw = $pcoll.find('names' => n)
      raw.each {|r| @results << r unless @results.include?(r)}
    end
    return @results.uniq
  end

  # Returns true or false depending on whether 0 or more MongoDB docs match
  # the Package object. Lookup is by name.
  def in_db?
    results = self.find_in_db
    if results.count == 0
      return false
    else
      return true
    end
  end

  # Creates an alphabetized, deduped array of libraries with active claims
  # on package. An active claim is one that is open. (no :out date is set)
  def active_libs
    d = self.find_in_db.first
    #puts "\n\nfind in db: #{d.inspect}"
    dp = Package.new.from_db(d)
    #puts "rehydrate db pkg: #{dp.inspect}"
    @inlibs = []
    @outlibs = []
    #puts "--"
    #puts "claims: #{dp[:claims].inspect}"
    dp[:claims].each do |e|
      if e[:type] == :in
        @inlibs << e[:lib]
        #puts "disposition: #{e.inspect} to @inlibs"
      else
        @outlibs << e[:lib]
        #puts "disposition: #{e.inspect} to @outlibs"
      end
    end
    #puts "--\ninlibs: #{@inlibs.inspect}\n#{@outlibs.inspect}"
    @active = @inlibs - @outlibs
    #puts "active: #{@active.inspect}"
    return @active.uniq.sort
    #puts "active, finished: #{@active.inspect}"
  end
  
  #Returns true (lib claiming pkg does not have an out date set) or 
  # false (lib does have an out date set)
  def active?
    d = self.active_libs
    if d.count > 0
      return true
    else
      return false
    end
  end
  # Returns a hash of all actively claimed packages in the db.
  # For each, returns an array of the package's names (key) and
  # an alphabetized, deduped array of libraries with active claims
  # on the package (value).
  def self.all_active_with_libs
    @rehydrated = []
    all = $pcoll.find.each {|pkg| @rehydrated << Package.new.from_db(pkg)}
    @result = {}

    @rehydrated.each do |pkg|
      a = pkg.active_libs
      @result[pkg[:names]] = a if a.size > 0
    end
    return @result
  end

  # Returns a hash of all actively claimed packages in the db.
  # For each, returns an array of the package's names (key) and
  # an alphabetized, deduped array of libraries with active claims
  # on the package (value).
  def self.all_loaded_with_libs
    @rehydrated = []
    $pcoll.find.each {|pkg| @rehydrated << Package.new.from_db(pkg)}
    @result = {}

    @rehydrated.each do |pkg|
      a = pkg.active_libs
      if a.size > 0
        if a.include?(:aalload) or a.include?(:hsl) or a.include?(:law)
          @result[pkg[:names]] = a
        end
      end
    end
    return @result
  end

  def self.all
    @rehydrated = []
    $pcoll.find.each {|pkg| @rehydrated << Package.new.from_db(pkg)}
    return @rehydrated
  end
    private

=begin rdoc
Populates +Package(new).from_csv[:claims]+ hash with data from the csv.
In the csv, there is one column per library. The header (key in the row hash) is
the library name. The package x library cell (value in the row hash) is blank if
that library has made no claim on the package. It is filled with a date
(m/d/yyyy) if the library has claimed the package.

If the claim is open, the value will simply be the date: 6/1/2010.
If the claim has been closed, a _d_ (for delete) is prepended to the date:
d7/1/2010.

This is called after the package name is set.
It does the following:
* removes +name+ pair from row hash
* if there is no date value, do nothing.
* if date value begins with a digit:
   :claims => {:aalload => {'6/1/2010' => :in}}
* if date value begins with a _d_:
   :claims => {:aalload => {'6/1/2010' => :out}}
=end
    def process_csv_claims(row)
      row.delete("name")
      row.each_pair do |k, v|
        if v == nil
          next
        elsif v =~ /^\d/
          @temp[:claims][k] = {v => :in}
        elsif v =~ /^d/
          @temp[:claims][k] = {v.gsub!(/^d/, '') => :out}
        end
      end
      return @temp
    end

  end






#  class PackageLookupById < Command
#    attr_reader :name
#    attr_accessor :package_id
#
#    def initialize(the_id)
#      @the_id = the_id
#      super("Looking up package with id #{@the_id}")
#    end #def initialize(name)
#
#    def execute
#      s = $package_coll.find_one(:_id => @the_id)
#      if s
#        @result = s
#      elsif s == nil
#        @result = nil
#      end
#      @result
#    end
#  end #class PackageIdLookupByName < Command
#  class PackageLookupByName < Command
#    attr_reader :name
#    attr_accessor :package
#
#    def initialize(name)
#      @name = name
#      super("Checking for package with name(s) #{@name}")
#    end #def initialize(name)
#
#    def execute
#      @found = []
#      s = $package_coll.find('names' => @name).each {|r| @found << r}
#      if @found.size > 1
#        @result = @found
#      elsif @found.size == 1
#        @result = @found
#      elsif s == nil
#        @result = []
#      end
#      @result
#    end
#  end #class PackageIdLookupByName < Command
#  class AddPackage < Command
#    def initialize(package)
#      @package = package
#      if @package.class != Package
#        puts "Only instances of Package may be added as packages."
#      end
#    end #def initialize(name)
#
#    def execute
#      $package_coll.insert(@package)
#    end #def execute
#  end #class CreatePackage < Command