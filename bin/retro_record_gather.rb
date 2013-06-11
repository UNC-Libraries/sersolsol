require 'marc'
require 'marc_sersol'

## goes through all original SerSol files
# identifies which files have records for a specific package
# opens those files
# extracts all retrospective records for a package into a new file

# Get array of directories in data/ssmrc/orig
dirs = Dir['data/ssmrc/orig/*']

# Get an array of all files in those directories
all_files = []
dirs.each {|dir| all_files << Dir["#{dir}/*"]}
all_files.flatten!
#puts all_files.inspect

# Get the name of the package for which you are compiling records
puts "Enter the name of the package."
pkg = gets.chomp
#puts pkg.inspect

#create array of files containing records for the package
pkg_files = []

#open each file and look record by record
#as soon as you find a record for the package, 
# put file name in pkg_files and move to next file.
all_files.each do |filename|
  file = File.new(filename)
  puts "Looking for #{pkg} records in #{File.basename(file)}..."
  pkg_present = 0
  
  until pkg_present != 0
    rec = file.gets(sep="\x1D")
    #puts rec.inspect
    if rec != nil
      pkg_present = 1 if rec.match("x#{pkg} ?\\x1E")
    else
      pkg_present = 9
    end
  end

  if pkg_present == 1
    pkg_files << filename
    puts "Found in #{filename}!\n\n"
  end

  file.close
end

puts pkg_files.inspect

#go to each file in pkg_files
#extract all records for the package

pkg_recs = []

pkg_files.each do |file|
  puts "Extracting #{pkg} records from #{file}..."
  matchcount = 0
  MARC::Reader.new(file).each do |rec| 
    if rec.packages.include?(pkg)
      pkg_recs << rec 
      matchcount += 1
    end
  end
  puts "Matches in #{file}: #{matchcount.to_s}"
end

pkg_recs.reverse!

path = "output/#{pkg}-all.mrc"
writer = MARC::Writer.new(path)

puts "Writing all records to file..."
pkg_recs.each do |rec|
  writer.write(rec)
end
writer.close
