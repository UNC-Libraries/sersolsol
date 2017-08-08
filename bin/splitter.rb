require 'rubygems'
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
puts "Reading in SerialsSolutions package instructions..."
pdata = CSV.read(Pkg_data, :headers => true)

pdata.each do |row|
  pnames = row['name']
  if row['aalload'] != nil
    dest = @aal_load_pkgs
  elsif row['hslload'] != nil
    dest = @hsl_load_pkgs
  elsif row['lawload'] != nil
    dest = @law_load_pkgs
  else
    dest = nil
  end
  pnames.split(";;;").each {|name| dest << name} if dest != nil
end

@all_loaded_packages = @aal_load_pkgs + @hsl_load_pkgs + @law_load_pkgs
@all_loaded_packages.flatten!

# Create and populate hash of existing SerSol recs in Millennium
puts "Reading in data on SerialsSolutions recs now in Millennium..."
exrec_data = CSV.read("data/mill_data.txt",
                      :headers => true,
                      :col_sep => "\t",
                      :quote_char => "\x00")
@exrecs = {}
exrec_data.each do |row|
  ssid = row['001']
  loc = row['LOCATION']
  bnum = row['RECORD #(BIBLIO)']
  @exrecs[ssid] = { 'bnum' => bnum }
  if loc.include?("noh")
    @exrecs[ssid]['loc'] = "hsl"
  elsif loc.include?("k")
    @exrecs[ssid]['loc'] = "law"
  else
    @exrecs[ssid]['loc'] = "aal"
  end
end

#Setup input mrc files
addmrc = "data/ssmrc/orig/#{The_year}/#{The_year}#{The_month}01add.mrc"
chmrc = "data/ssmrc/orig/#{The_year}/#{The_year}#{The_month}01change.mrc"
delmrc = "data/ssmrc/orig/#{The_year}/#{The_year}#{The_month}01delete.mrc"

# PRE PROCESSING ALL INCOMING RECORDS

# Populate hash with all loaded package names and associated 773 titles
# So we can add package name 773
puts "Assigning 773 value to each package..."
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

# Populate hash with all loaded package names and associated 506s
# So we can add package 506s

puts "Assigning 506$f value to each package..."
pdata = CSV.read(Pkg_data, :headers => true)
@h506 = {}
pdata.each do |row|
  pnames = row['name']
  if row['506access'] != nil
    pnames.split(";;;").each do |name|
      @h506[name] = row['506access']
    end
  end
end

# Performs edits on the MARC::Record passed in
# Returns the edited MARC::Record
def edit_marc_rec(rec)
  # This comes first because it is the most important part
  # Add 773s and 506s
  pkg_names = rec.packages
  pkg_names.each do |name|
    the_773 = @h773[name]
    the_506f = @h506[name]
    if @all_loaded_packages.include? name
      # the 773 part
      if the_773 != nil
        rec.append(MARC::DataField.new( '773', '0', ' ', ['t', the_773]))
      else
        @warnings << "The package #{name} has no associated 773 value."
      end
      
      if the_506f != nil
        unless the_506f == "na varies per title"
          rec.append(MARC::DataField.new( '506', '1', ' ', ['a', 'Access limited to UNC Chapel Hill-authenticated users.'], ['f', the_506f]))
        end
      else
        @warnings << "The package #{name} has no associated 506f value."
      end
    end
  end

  # The rest of the edits are organized by MARC field
  # 020 -- Delete 020 |c or |9 and provide |q
  @m020 = rec.fields("020")
  if @m020.count > 0
    @m020.each do |f|
      @sfs = f.codes
      exclude_sfs = ['c', '9']
      has_bad = @sfs & exclude_sfs
      if has_bad.count > 0
        newfield = MARC::DataField.new(f.tag, f.indicator1, f.indicator2)
        f.each do |sf|
          if sf.code =~ /[^c9]/
            newfield.append(MARC::Subfield.new(sf.code, sf.value))
          end
        end
        rec.append(newfield) unless has_bad.count == @sfs.count
        rec.fields.delete(f)
      end
    end
  end

  # Delete |9 from 044
  @m044 = rec.fields("044")
  if @m044.count > 0
    @m044.each do |f|
      @sfs = f.codes
      if @sfs.include? "9"
        newfield = MARC::DataField.new(f.tag, f.indicator1, f.indicator2)
        f.each do |sf|
          if sf.code != "9"
            newfield.append(MARC::Subfield.new(sf.code, sf.value))
          end
        end
        rec.append(newfield) if @sfs.count > 1
        rec.fields.delete(f)
      end
    end
  end

  # Change 060 |i to |b
  @m060 = rec.fields("060")
  if @m060.count > 0
    @m060.each do |f|
      @sfs = f.codes
      if @sfs.include? "i" 
        newfield = MARC::DataField.new(f.tag, f.indicator1, f.indicator2)
        f.each do |sf|
          if sf.code != "9"
            newfield.append(MARC::Subfield.new(sf.code, sf.value))
          else
            newfield.append(MARC::Subfield.new('b', sf.value))
          end
        end
        rec.append(newfield)
        rec.fields.delete(f)
      end
    end
  end

  # Move 088 |9 content to beginning of |a
  @m088 = rec.fields("088")
  if @m088.count > 0
    @m088.each do |f|
      @sfs = f.codes
      if @sfs.include? "9" 
        newfield = MARC::DataField.new(f.tag, f.indicator1, f.indicator2)
        sfa = ""
        sf9 = ""
        other_sfs = []
        f.each do |sf|
          if sf.code == "a"
            sfa = sf.value
          elsif sf.code == '9'
            sf9 = sf.value
          else
            other_sfs << sf
          end
        end
        new_sfa = "#{sf9} #{sfa}"
        newfield.append(MARC::Subfield.new('a', new_sfa))
        if other_sfs.count > 0
          other_sfs.each do |sf|
            newfield.append(MARC::Subfield.new(sf.code, sf.value))
          end
        end
        rec.append(newfield)
        rec.fields.delete(f)
      end
    end
  end

  # Delete $y from 1XX, 240
  @the1xx = rec.find_all {|field| field.tag =~ /^(1..|240)/}
  if @the1xx.count > 0
    @the1xx.each do |f|
      @sfs = f.codes
      if @sfs.include? "y"
        newfield = MARC::DataField.new(f.tag, f.indicator1, f.indicator2)
        f.each do |sf|
          if sf.code != "y"
            newfield.append(MARC::Subfield.new(sf.code, sf.value))
          end
        end
        rec.append(newfield)
        rec.fields.delete(f)
      end
    end
  end
  
  # Split repeated 590|a into multiple fields
  @m590 = rec.fields("590")
  if @m590.count > 0
    @m590.each do |f|
      @sfs = []
      f.subfields.each do |s|
        @sfs << s.code
      end
      if @sfs.include? "a"
        if @sfs.count("a") > 1
          f.each do |sf|
            if sf.code == "a"
              newfield = MARC::DataField.new(f.tag, f.indicator1, f.indicator2)
              newfield.append(MARC::Subfield.new(sf.code, sf.value))
              rec.append(newfield)
            end
          end
          rec.fields.delete(f)
        end
      end
    end
  end

  # 710s - delete some 710s:
  rec.each_by_tag("710") do |m710|
    deleteme = "no"
    sfa = m710.find_all {|sf| sf.code == 'a'}
    sfa.each do |sf|
      deleteme = "yes" if /^SpringerLink \(Online service\).? */ =~ sf.value
      deleteme = "yes" if /^Springer Science+Business Media.? */ =~ sf.value
    end
    rec.fields.delete(m710) if deleteme == "yes"
  end
  
  # 773s - delete some 773s:
  rec.each_by_tag("773") do |m773|
    deleteme = "no"
    sft = m773.find_all {|sf| sf.code == 't'}
    sft.each do |sf|
      deleteme = "yes" if /^ACLS Humanities E-Book.? *$/ =~ sf.value
      deleteme = "yes" if /^Engineering Societies Library Collection \(Library of Congress\) *$/ =~ sf.value
      deleteme = "yes" if /^Springer eBooks *$/ =~ sf.value
    end
    rec.fields.delete(m773) if deleteme == "yes"
  end
  
  return rec
end

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

aaldel_bnums = File.open("data/ssmrc/split_lib/#{The_year}#{The_month}01_aal_del_bnums.txt", "w")
hsldel_bnums = File.open("data/ssmrc/split_lib/#{The_year}#{The_month}01_hsl_del_bnums.txt", "w")
lawdel_bnums = File.open("data/ssmrc/split_lib/#{The_year}#{The_month}01_law_del_bnums.txt", "w")

# Split add records
if File.file?(addmrc)
  puts "Processing add file..."
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
      lawadd.write(edit_marc_rec(r))
    elsif hslrec == 1
      hsladd.write(edit_marc_rec(r))
    elsif aalrec == 1
      aaladd.write(edit_marc_rec(r))
    else
      noadd.write(r)
    end
  end
end

#Split change records into loaded and not loaded
if File.file?(chmrc)
  puts "Processing change file..."
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
    chrec = 0

    pkg_names = r.packages
    pkg_names.each do |name|
      chrec = 1 if @incat.include?(name)
    end
    if chrec == 1
      changes.write(edit_marc_rec(r))
    elsif chrec == 0
      ssid = r['001'].value
      lib = @exrecs[ssid]['loc']
      bnum = @exrecs[ssid]['bnum']
      case lib
      when "aal"
        aaldelete.write(edit_marc_rec(r))
        aaldel_bnums.write(bnum + "\n")
      when "hsl"
        hsldelete.write(edit_marc_rec(r))
        hsldel_bnums.write(bnum + "\n")
      when "law"
        lawdelete.write(edit_marc_rec(r))
        lawdel_bnums.write(bnum + "\n")
      end
    end
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
      lawadd.write(edit_marc_rec(r))
    elsif hslrec == 1
      hsladd.write(edit_marc_rec(r))
    elsif aalrec == 1
      aaladd.write(edit_marc_rec(r))
    else
      nochanges.write(r)
    end
  end
end

#Gather loaded delete records
if File.file?(delmrc)
  puts "Processing delete file..."
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
    lib = @exrecs[ssid]['loc']
    bnum = @exrecs[ssid]['bnum']
    case lib
      # we don't 'need' to edit these MARC records, but doing so gives
      # us 773s in the delete files; write unedited marc if this causes
      # problems
      when "aal"
        aaldelete.write(edit_marc_rec(r))
        aaldel_bnums.write(bnum + "\n")
      when "hsl"
        hsldelete.write(edit_marc_rec(r))
        hsldel_bnums.write(bnum + "\n")
      when "law"
        lawdelete.write(edit_marc_rec(r))
        lawdel_bnums.write(bnum + "\n")
      end
  end
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
aaldel_bnums.close
hsldel_bnums.close
lawdel_bnums.close

# Split HSL per package
puts "Splitting HSL adds into separate files per package..."
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

# Generate summary count of deleted records by 773
del_mrcs = ["data/ssmrc/split_lib/#{The_year}#{The_month}01_aal_delete.mrc",
"data/ssmrc/split_lib/#{The_year}#{The_month}01_hsl_delete.mrc",
"data/ssmrc/split_lib/#{The_year}#{The_month}01_law_delete.mrc"]
del_mrcs.each do |mrc_path|
  next if !File.file?(mrc_path)
  summary_path = mrc_path.gsub("_delete.mrc", "_del_summary.txt")
  m773s = []
  reader = MARC::Reader.new(mrc_path)
  reader.each do |rec|
    rec.each_by_tag("773") do |m773|
      sft = m773.find_all {|sf| sf.code == 't'}
      sft.each do |sf|
        m773s << sf.value
      end
    end
  end
  # generate arr of 773s, counts; sorted by count descending
  summary = m773s.group_by{ |x| x }.map{ |k, v| [k, v.length] }.sort_by{ |x| [-x[1], x[0]] }
  File.open(summary_path, 'w') do |file|
    summary.each { |m773_count| file << m773_count.join("\t") + "\n" }
  end
end

puts "Done!"

@warnings.uniq!
if @warnings.size > 0
  puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
  puts "WARNINGS"
  puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="

  @warnings.each do |w|
    puts w
  end
end
