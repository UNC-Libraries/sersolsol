require './lib/setup'
require 'marc'
require 'marc_sersol'
#require 'mongo'
#  $db = Mongo::Connection.new.db('run1')
#  $pcoll = $db['packages']


=begin rdoc
This class checks a MARC file to make sure all packages in that file's records
are in the package database:
* opens MARC file and reads records
* reads each record and pushes its package names to @all_pkg_names
* iterates over @all_pkg_names, keeping only unique names
* for each unique name in @all_pkg_names
** looks up each of its names in the db
** puts names not found in log :new
** puts names where more than one is found in log :ambiguous
** puts names where one is found in log :existing
=end

class PackagePrechecker < Command

  # *Arguments*
  # [mrcfile] Path to the MARC file you want to check.
  # *Usage*
  #    pre = PackagePrechecker('path/to/marc.mrc').new.execute
  attr_reader :log
  def initialize(mrcfile)
    @mrc = mrcfile
    @log = {:new => ['New package names', []],
      :ambiguous => ['Ambiguous package names', []],
      :existing => ['Existing package names', []]}
  end

  def execute
    # opens marc file and gets records
    reader = MARC::Reader.new(@mrc)

    @all_pkg_names = []

    reader.each do |r|
      pkg_names = r.packages
      pkg_names.each {|name| @all_pkg_names << name}
    end

    @all_pkg_names.uniq!

    @all_pkg_names.each do |name|
      dbps = $pcoll.find('names' => name)
      if dbps.count == 0
        @log[:new][1] << name
      elsif dbps.count > 1
        @log[:ambiguous][1] << name
      else
        @log[:existing][1] << name
      end
    end
    return self
  end

  def report_to_screen
    @log.each_pair do |k, v|
      puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
      puts "#{v[1].count} #{v[0].upcase}"
      puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
      v[1].each {|e| puts e}
    end
  end
end