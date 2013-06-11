require 'setup'
require 'marc'
require 'fastercsv'
require 'timer'
require 'facets'

def print_r(text, size=80)
  print "\r#{text.ljust(size)}"
  STDOUT.flush
end

timer = Timer.new
timer.time("Done!") do
  
  the_file = ARGV[0]
  the_date = ARGV[1]
  the_type = ARGV[2]
  
  puts "Reading file..." 
  recs = []
  MARC::Reader.new(the_file).each {|rec| recs << rec}
  
  puts "Counting..."
  index = 0
  count = recs.size
  step = count / 100
  
  ps = {}
  
  Package.all.each {|pkg| ps[pkg.name] = 0}  
  
  
  recs.each do |r|
    pkgs = r.packages    
    
    puts r.ssid if pkgs == nil
    
    pkgs.ergo.each do |pkg|
      if ps[pkg] == nil
        puts pkg
        else
      ps[pkg] = ps[pkg] += 1
      end
    end #pkgs.each do |package|
    
    index = index += 1
    if index % step == 0 
      print_r(
        "%d of %d (%d%%)" %
      [index, count, (index.to_f/count * 100)]
      )
    end
  end #reader.each do |r|
  
  to_write = []
  
  ps.each_pair do |k, v|
  v = v * -1 if the_type == "delete"
  if v > 0 || v < 0
  po = Package.lookup(k)
  to_write << [po.name, po.libs.to_s, v, the_date]
  end #if v > 0
  end #ps.each_pair do |k, v|
  
  to_write.each {|e| puts e.join("\t")}
  
    out = FasterCSV.open('output/counts.csv', "a") do |csv|
#    csv << ["Package name", "Library(s)", "Count", "Type", "Date"]
     to_write.each {|e| csv << e}
  end #output = FasterCSV.open('data/processed.csv', "w") do |csv|
end 