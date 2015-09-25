require 'highline/import'
require 'marc'
require 'marc_sersol'
require 'csv'

Pkg_data = "data/pkg_list.csv"
the_date = ask("Enter month you are processing in the format: YYYYMM")
The_year = the_date[0..3]
The_month = the_date[4..5]
puts "the year = #{The_year}"
puts "the month = #{The_month}"
puts "the day = 01"

#Create array to hold warnings to report at the end
@warnings = []

#Create lists of packages to load for each library
@aal_load_pkgs = []
@hsl_load_pkgs = []
@law_load_pkgs = []
        
#Populate lists of packages to load for each library
pdata = CSV.read(Pkg_data, :headers => true)
         
pdata.each do |row|
  pnames = row['name']
  if row['aalload'] != nil
    dest = @aal_load_pkgs
  elsif row['hsl'] != nil
    dest = @hsl_load_pkgs
  elsif row['law'] != nil
    dest = @law_load_pkgs
  else
    dest = nil
  end
  pnames.split(";;;").each {|name| dest << name} if dest != nil
end
      
# Create and populate hash of existing SerSol recs in Millennium
exrec_data = CSV.read("data/mill_data.csv", :headers => true)
@exrecs = {}
exrec_data.each do |row|
  ssid = row['1']
  loc = row['LOCATION']
  if loc.include?("noh")
    @exrecs[ssid] = "hsl"
  elsif loc.include?("k")
    @exrecs[ssid] = "law"
  else
    @exrecs[ssid] = "aal"
  end 
end
        
#Setup input mrc files 
addmrc = "data/ssmrc/orig/#{The_year}/#{The_year}#{The_month}01add.mrc"
chmrc = "data/ssmrc/orig/#{The_year}/#{The_year}#{The_month}01change.mrc"
delmrc = "data/ssmrc/orig/#{The_year}/#{The_year}#{The_month}01delete.mrc"

# PRE PROCESSING ALL INCOMING RECORDS
# Add package name 773

# Populate hash with all loaded package names and associated 773 titles
pdata = CSV.read(Pkg_data, :headers => true)
@h773 = {}
pdata.each do |row|
  pnames = row['name']
  if row['773title'] != nil
    pnames.split(";;;").each do |name|
      @h773[name] = row['773title']
    end
  end
end

def add_773(file)
  reader = MARC::Reader.new(file)
  @recs = []
  
  reader.each do |rec|
    pkg_names = rec.packages
    pkg_names.each do |name| 
      the_773 = @h773[name]
      if the_773 != nil
        rec.append(MARC::DataField.new( '773', '0', ' ', ['t', the_773]))
      else
        @warnings << "The package #{name} has no associated 773 value."
      end
    end
    @recs << rec
  end
  writer = MARC::Writer.new(file)
  @recs.each {|r| writer.write(r)}
  writer.close
end

puts "Adding 773 to new records..."
add_773(addmrc)
puts "Adding 773 to change records..."
add_773(chmrc)
puts "Adding 773 to delete records..."
add_773(delmrc)

# Set up files and writers required for splitting
aaladd = MARC::Writer.new("data/ssmrc/split_lib/#{The_year}#{The_month}01_aal_add.mrc")
hsladd = MARC::Writer.new("data/ssmrc/split_lib/#{The_year}#{The_month}01_hsl_add.mrc")
lawadd = MARC::Writer.new("data/ssmrc/split_lib/#{The_year}#{The_month}01_law_add.mrc")
noadd = MARC::Writer.new("data/ssmrc/split_lib/#{The_year}#{The_month}01_NO_add.mrc")

changes = MARC::Writer.new("data/ssmrc/split_lib/#{The_year}#{The_month}01_change.mrc")
nochanges = MARC::Writer.new("data/ssmrc/split_lib/#{The_year}#{The_month}01_NO_change.mrc")

aaldelete = MARC::Writer.new("data/ssmrc/split_lib/#{The_year}#{The_month}01_aal_delete.mrc")
hsldelete = MARC::Writer.new("data/ssmrc/split_lib/#{The_year}#{The_month}01_hsl_delete.mrc")
lawdelete = MARC::Writer.new("data/ssmrc/split_lib/#{The_year}#{The_month}01_law_delete.mrc")
nodelete = MARC::Writer.new("data/ssmrc/split_lib/#{The_year}#{The_month}01_NO_delete.mrc")

# Split add records
add_reader = MARC::Reader.new(addmrc)
add_reader.each do |r|
  pkg_names = r.packages
  lawrec = 0
  hslrec = 0
  aalrec = 0
  
  pkg_names.each do |name| 
    if @law_load_pkgs.include?(name)
      lawrec = 1
    elsif @hsl_load_pkgs.include?(name)
      hslrec = 1
    elsif @aal_load_pkgs.include?(name)
      aalrec = 1
    end
  end
  
  if lawrec == 1
    lawadd.write(r)
  elsif hslrec == 1
    hsladd.write(r)
  elsif aalrec == 1
    aaladd.write(r)
  else
    noadd.write(r)
  end
end
        
#Split change records into loaded and not loaded
ch_reader = MARC::Reader.new(chmrc)
@chloaded = []
@chunloaded = []
ch_reader.each do |r|
  ssid = r['001'].value
  if @exrecs.has_key?(ssid)
    @chloaded << r
    #puts "ssid #{ssid} found. moved to chloaded."
  else
    @chunloaded << r
    #puts "ssid #{ssid} not found. moved to chunloaded."
  end
end
        
# Create list of all loaded packages
@incat = @aal_load_pkgs + @hsl_load_pkgs + @law_load_pkgs
        
# PROCESS LOADED CHANGE RECORDS
# Is record still in loaded package(s)? 
# If so, write to change file.
# If no, get location and write to its delete file.
@chloaded.each do |r|
  lawrec = 0
  hslrec = 0
  aalrec = 0
  chrec = 0
  
  pkg_names = r.packages
  pkg_names.each do |name| 
    chrec = 1 if @incat.include?(name)
  end
    if chrec == 0
      ssid = r['001'].value
      lib = @exrecs[ssid]
      aalrec = 1 if lib == "aal"
      hslrec = 1 if lib == "hsl"
      lawrec = 1 if lib == "law"
    end

  
changes.write(r) if chrec == 1
aaldelete.write(r) if aalrec == 1
hsldelete.write(r) if hslrec == 1
lawdelete.write(r) if lawrec == 1
end
        
#PROCESS UNLOADED CHANGE RECORDS
# Is record now in a loaded package (per library?)
# If yes, write to library's add file
@chunloaded.each do |r|
pkg_names = r.packages
lawrec = 0
hslrec = 0
aalrec = 0
  
pkg_names.each do |name| 
  if @law_load_pkgs.include?(name)
    lawrec = 1
  elsif @hsl_load_pkgs.include?(name)
    hslrec = 1
  elsif @aal_load_pkgs.include?(name)
    aalrec = 1
  end
end
  
if lawrec == 1
  lawadd.write(r)
elsif hslrec == 1
  hsladd.write(r)
elsif aalrec == 1
  aaladd.write(r)
else
  nochanges.write(r)
end
end
        
                
#Gather loaded delete records
del_reader = MARC::Reader.new(delmrc)
@delloaded = []
del_reader.each do |r|
ssid = r['001'].value
if @exrecs.has_key?(ssid)
  @delloaded << r 
else
  nodelete.write(r)
end
end
        
# Split deleted records per library
@delloaded.each do |r|
ssid = r['001'].value
lib = @exrecs[ssid]
aaldelete.write(r) if lib == "aal"
hsldelete.write(r) if lib == "hsl"
lawdelete.write(r) if lib == "law"
end
        
aaladd.close
hsladd.close
lawadd.close  
noadd.close
changes.close
nochanges.close
aaldelete.close
hsldelete.close
lawdelete.close
nodelete.close

# Split HSL per package
hsladds = MARC::Reader.new("data/ssmrc/split_lib/#{The_year}#{The_month}01_hsl_add.mrc")

@hsltowrite = {}

hsladds.each do |r|
  pkg_names = r.packages
  pkg_names.each do |name|
    if @hsl_load_pkgs.include?(name)
      if @hsltowrite.has_key?(name)
        @hsltowrite[name] << r
      else
        @hsltowrite[name] = [r]
      end
    end
  end
end

@hsltowrite.each_pair do |k, v|
  kclean = k.gsub(/[^a-z0-9]+/i, '-')
  file = "data/ssmrc/split_lib/#{The_year}#{The_month}01_hsl_add_#{kclean}.mrc"
  writer = MARC::Writer.new(file)
  v.each {|r| writer.write(r)}
  writer.close
end

@warnings.uniq!
if @warnings.size > 0
  puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
  puts "WARNINGS"
  puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="

  @warnings.uniq!.each do |w|
    puts w
  end
end
