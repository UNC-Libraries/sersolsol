require 'highline/import'
require 'marc'
require 'marc_sersol'
require 'csv'
require 'strscan'

the_date = ask("Enter month you are processing in the format: YYYYMM")
The_year = the_date[0..3]
The_month = the_date[4..5]
puts "the year = #{The_year}"
puts "the month = #{The_month}"
puts "the day = 01"

Pkg_data = "data/pkg_list.csv"
        
class QuitOrMain
  def initialize
    puts "\n\nWhat next?"
    choose do |menu|
      menu.choice :back_to_main_menu do MainMenu.new end
      menu.choice :quit do exit end
    end
  end
end

class MainMenu
  def initialize
    puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
    puts "Welcome to SerSolSol"
    puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
    
    
    puts "What needs to be done?"
    choose do |menu|

      menu.choice :rename_sersol_files do
        dirpath = "data/ssmrc/orig/#{The_year}"
        @ssstem = "_NO_360MARC_Update_monographs_"
        sstypes = {"changed" => "change", 
          "deleted" => "delete", 
          "new" => "add"}
                
        def rename_files(oldtype, newtype)
          File.rename("#{@ssstem}#{oldtype}.mrc", "#{The_year}#{The_month}01#{newtype}-o.mrc")
        end      
                
        Dir.chdir(dirpath) do
          sstypes.each_pair {|o,n| rename_files(o, n)}
        end
        
        QuitOrMain.new
      end
      
      menu.choice :localize_ssj_numbers_in_files do
        dirpath = "data/ssmrc/orig/#{The_year}"
        
        def localize(type)
          oldmrc = "#{The_year}#{The_month}01#{type}-o.mrc"
          newmrc = "#{The_year}#{The_month}01#{type}.mrc"
          recs = []
          MARC::Reader.new(oldmrc).each {|rec| recs << rec}
          writer = MARC::Writer.new(newmrc)
          puts "Localizing #{type} records..."
          recs.each do |rec|
            rec.localize001
            writer.write(rec)
          end
          writer.close()
        end
        
        types = ["add", "change", "delete"]
        Dir.chdir(dirpath) do
          types.each {|type| localize(type)}
        end
        QuitOrMain.new
      end
      
      menu.choice :check_packages_in_add_file do
        # opens marc file and gets records
        addmrc = "data/ssmrc/orig/#{The_year}/#{The_year}#{The_month}01add.mrc"
        reader = MARC::Reader.new(addmrc)
      
        @mrc_pkg_names = []

        reader.each do |r|
          pkg_names = r.packages
          pkg_names.each {|name| @mrc_pkg_names << name}
        end

        @mrc_pkg_names.uniq!

        pdata = CSV.read(Pkg_data, :headers => true)
        
        @csv_pkg_names = []
        
        pdata.each do |row|
          pnames = row['name']
          pnames.split(";;;").each {|name| @csv_pkg_names << name}
        end
        
        pkg_hash = {"known" => [], "new" => []}
        
        @mrc_pkg_names.each do |mrcname|
          if @csv_pkg_names.include?(mrcname)
            pkg_hash["known"] << mrcname
          else
            pkg_hash["new"] << mrcname
          end
        end
        
        puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
        puts "NEW PACKAGES"
        puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
        puts "#{pkg_hash["new"].size.to_s} new packages"
        if pkg_hash["new"].size > 0 
          pkg_hash["new"].sort!.each {|n| puts n}
        end
        
        puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
        puts "KNOWN PACKAGES"
        puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
        puts "#{pkg_hash["known"].size.to_s} known packages"
        if pkg_hash["known"].size > 0 
          pkg_hash["known"].sort!.each {|n| puts n}
        end
        
        QuitOrMain.new
      end
      
      menu.choice :extract_records_to_load do
      
    
      end
      
      menu.choice :extract_package_marc_from_file do
        path = ask("Enter path to file\n")
        pkg = ask("Enter name of package to extract\n")
        ps = StringScanner.new(path)
        ps.scan /^(.*\/)([^\/]*)(\.mrc)$/
        file = ps[2]
        @recs = []
        MARC::Reader.new(path).each {|rec| @recs << rec if rec.packages.include?(pkg)}
        pkgclean = pkg.gsub(/[^a-z0-9]+/i, '-')
        path = "output/#{file}-#{pkgclean}.mrc"
        writer = MARC::Writer.new(path)

        @recs.each do |rec|
          writer.write(rec)
        end
        writer.close
        QuitOrMain.new
      end

      menu.choice :extract_all_packages_to_separate_marc_files do
        path = ask("Enter path to file\n")
        ps = StringScanner.new(path)
        ps.scan /^(.*\/)([^\/]*)(\.mrc)$/
        file = ps[2]
        @recs = []

        MARC::Reader.new(path).each {|rec| @recs << rec }

        @pkgs = {}
        @recs.each do |rec|
          pkgs = rec.packages
          pkgs.each do |pkg|
            unless @pkgs.has_key? pkg
              @pkgs[pkg] = []
            end
            @pkgs[pkg] << rec
          end
        end

        @pkgs.each_pair do |k, v|
          puts "#{v.size} records: #{k}"
          kfilename = k.gsub(/([^-A-Za-z0-9_,@ ])/n, ' ')
          po = Package.new.from_db($pcoll.find('names' => k).first)
          libs = po.active_libs.join ","
          path = "output/#{file}-#{libs}-#{kfilename}.mrc"
          writer = MARC::Writer.new(path)
          v.each do |rec|
            writer.write(rec)
          end
          writer.close
        end
        QuitOrMain.new
      end
    end
  end
end


MainMenu.new
# :show_package_report
# :count_active_records_in_a_package
# :extract_records_for_a_library_from_a_file
# :extract_records_for_a_package_from_a_file
# :add_info_from_a_file_to_the_record_database
# :add_records_from_a_file_to_the_record_database
# :output_quality_report