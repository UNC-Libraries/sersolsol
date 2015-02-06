require 'csv'
require 'marc'

pkgfile = "data/pkg_list.csv"
pkgdata = CSV.read(pkgfile, :headers => true)

# Create array to hold packages that should be loaded
@lpkgs = []

pkgdata.each do |row|
  keep = 0
  keep += 1 if row['aalload'] != nil
  keep += 1 if row['hsl'] != nil
  keep += 1 if row['law'] != nil

  if keep > 0
    row['name'].split(";;;").each {|name| @lpkgs << name}
  end
end

millfile = File.open('data/mill_pkg_data.txt', "r").read
milldata = millfile.split(/\n/)

#get rid of millfile headers
milldata.shift

#Creates array of bnums that should be deleted
@delete_recs = [["bnum", "packages"]]

milldata.each do |ln|
  brk = ln.split("\t")
  bnum = brk.shift.delete'"'
  brk[0].delete!'"'
  @pkgs = brk.shift.split(";")

  keep = 0
  @pkgs.each do |pkg|
    keep += 1 if @lpkgs.include? pkg
  end

  if keep == 0
    sendit = [bnum, @pkgs.to_s]
    @delete_recs << sendit
  end
end

if @delete_recs.count > 0
  CSV.open("output/recs_to_delete.csv", 'wb') do |csv|
    @delete_recs.each {|r| csv << r}
  end
  else
  puts "No records need to be deleted."
end


exit
