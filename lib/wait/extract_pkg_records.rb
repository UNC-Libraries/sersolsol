
require 'marc'


timer = Timer.new
timer.time("Done!") do
  
file = ARGV[0]
pkgid = ARGV[1]

recs = []
MARC::Reader.new(file).each {|rec| recs << rec}

pkgrecs = []

pkg = Package.find(pkgid).name

counter = 0

recs.each do |rec|
  pkgs = rec.packages
  pkgrecs << rec if pkgs.include?(pkg)
  
end #recs.each do |rec|
  
  
w = MARC::Writer.new("output/#{pkg.gsub!(/ |\//, "_")}.mrc")

pkgrecs.each do |p| 
  w.write(p)
  counter += 1
end #pkgrecs.each do |p|
  
  puts counter
  
  end #timer