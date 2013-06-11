# ruby 1.9
# runs on .mrc file
# usage:
# ruby extract_field_value.rb path/to/dir

require "marc"
require "marc_sersol"
require "csv"

Dir.chdir ARGV[0]
files = File.join("**", "*delete.mrc")
fs = Dir.glob files

p Dir.pwd

files = []

fs.each {|f| files << "#{Dir.pwd}/#{f}"}

files.each {|f| puts f}

the001s = []

files.each do |f|
@recs = []
MARC::Reader.new(f).each {|rec| the001s << [rec.localize001, f]}
end

CSV.open("extracted_field_values.csv", "w") do |c|
  the001s.each do |r|
  c << r
  end
end

  