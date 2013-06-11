
require 'marc'
require 'timer'

timer = Timer.new
timer.time("Done!") do
  
  lib = ARGV[0]
  date = ARGV[1]
  
#split = ExtractLibRecords.new(lib, "ssmrc/orig/#{date}add.mrc", "output/#{lib}_#{date}_add.mrc")
#split.execute

split = ExtractLibRecords.new(lib, "ssmrc/orig/#{date}change.mrc", "output/#{lib}_#{date}_change.mrc")
split.execute

#split = ExtractLibRecords.new(lib, "ssmrc/orig/#{date}delete.mrc", "output/#{lib}_#{date}_delete.mrc")
#split.execute
end #timer