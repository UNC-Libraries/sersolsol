require './lib/manager/command'
require 'marc'
require 'marc_sersol'

=begin rdoc
The liason between sersol record state data in the csv file and in the db.
Allows methods to be associated with States, which can be read from and written
to the db.

A State is a snapshot of information about a MARC record. The MARC record that
is the subject of the State record is identified by the SSID field in the State
record. This matches the SerSol id number in the 001 field of the MARC record.

Because various versions of a single MARC record may be received from SerSol,
state is tracked. This allows the history of a record, of a package, or of all
record loads to be reconstructed if necessary.

*Structure of a SerSol record state record*
- SSID: the SerSol id from the 001 field. For ebooks, transformed.
- Date: the date associated with the load file received from SerSol
- Loaded?: whether or not the record described by this state is in the catalog
- Packages: what packages are listed in the 856$x(es)
- Libs: deduplicated, alphabetic list of all libraries claiming said packages
- Type: :add, :change, or :delete
- Error: records error message(s) thrown during processing

- Create new states for all in each file. Populates:
-- SSID - pulls from MARC record. Transformation applied if ebook.
-- Date - entered by user
-- Packages - pulls from MARC record.
-- Type - entered by user
-- Working? - automatically true

- Create dictionary of packages/libraries
- Create array for AAL, HSL, LAW

ADDS

-- Is there an existing State for this record?
--- IF YES: Is it Loaded?
---- IF YES: Record error.
---- IF NO: continue
--- IF NO: continue

-- Populate Libs for State
-- Calculate Loaded? value. If it is:
--- TRUE: push MARC to array for library
--- FALSE: continue

CHANGES

-- Is there an existing State for this record?
--- If NO: Record error
--- If YES: Find the most recent state for this record

-- Populate Libs for State
-- Calculate Loaded? value. If it is:
--- TRUE
---- If previous record is loaded: Push to Changes file
---- If previous record is not loaded: Push to Adds file(s) for lib(s) loading
       record
--- FALSE
---- If previous record is loaded: Push to appropriate Deletes file (for lib(s)
       that have lost holdings
---- If previous record is not loaded: continue

DELETES

-- Is there an existing State for this record?
--- If NO: Record error
--- If YES: Find the most recent state for this record

-- Populate Libs for State
-- Calculate Loaded? value. If it is:
--- TRUE
---- If previous record is loaded: Push to appropriate Deletes file for lib(s)
     losing holdings
---- If previous record is not loaded: Log warning and continue
--- FALSE
---- If previous record is loaded: Push to appropriate Deletes file (for lib(s)
       that have lost holdings
---- If previous record is not loaded: continue

FINISH

- Write MARC output to files:
-- AAL adds
-- HSL adds
-- Law adds
-- Changes
-- AAL deletes
-- HSL deletes
-- Law deletes

- Write reports to csv:
-- SSID -- Title -- Packages

=end
class State < Hash
  attr_accessor :dbid
  # Create an instance of the class. Instance variables are set
  # by calling from_csv or from_db immediately after instantiation.
  #    state_from_db = State.new.from_db(state_bson_ordered_hash)
  #    state_from_marc = State.new.from_marc(marc_record)
  def initialize
  end

=begin rdoc
Returns an instance of State populated with data from a MARC record. Populates:
-- SSID - pulls from MARC record. Transformation applied if ebook.
-- Date - entered by user
-- Packages - pulls from MARC record.
-- MARC
-- Type - entered by user
-- Working? - automatically true
*Arguments*
[marc] Expects a MARC record
[date] Expects a Date object that will be passed in from above (user will enter
date when starting the record ingest process.)
[type] Expects a type symbol that will be passed in from above (user will enter
type when starting the record ingest process.) Allowed values: :add, :change,
:delete
=end
  def from_marc(marc, date, type)
    marc.localize001
    self[:ssid] = marc['001'].value
    self[:date] = date
    self[:packages] = marc.packages
    self[:type] = type
    return self
  end


  # Returns an instance of State populated with data from MongoDB document.
  # States in MongoDB are edited by getting a state document from the db,
  # creating a new +State+ object from that db document, editing the +Package+
  # object, and then using the save method to update it in the db.
  # *Arguments*
  # [bh] A BSON::OrderedHash
  # *Usage*
  # Assumes a MongoDB collection named +states+.
  #    dbstate = states.find(:ssid => 'sse0001234').first
  #    a_state = State.new.from_db(dbstate)
  # (Make changes to the Package instance)
  #    a_state.save
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
    #marchash = self[:marc]
    #self[:marc] = MARC::Record.new_from_marchash(marchash)
    return self
  end

  # Saves the State object back to the database, updating the existing
  # document.
  # *Usage* -- See #from_db
  def save
    $scoll.update({'_id' => @dbid}, self)
  end

  # Returns array of MongoDB docs matching the State object.
  # Lookup is by ssid.
  # Results are returned sorted descending by date (i.e. most recent will
  # be first.
  def find_in_db
    @results = []
    raw = $scoll.find('ssid' => self[:ssid])
    raw.each {|r| @results << r}
    @results
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

  # Creates an alphabetized, deduped array of libraries holding this item (i.e.
  # libraries with active claims on the item's packages.

  def libs
    @libs = []
    self[:packages].each do |pkg|
      prec = $pcoll.find('names' => pkg).first
      pprec = Package.new.from_db(prec)
      @libs << pprec.active_libs
    end
    @libs.flatten.uniq.sort
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

  def loaded?
    libs = self.libs
    if libs.include?(:aalload) or libs.include?(:hsl) or libs.include?(:law)
      return true
    else
      return false
    end
  end

end

