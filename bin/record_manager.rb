require 'highline/import'
require './lib/setup'
require 'marc'
require 'marc_sersol'
require 'csv'
require 'strscan'

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
      menu.choice :check_packages_in_files_before_loading do
        mrc = ask("Enter path to MARC file")
        pre = PackagePrechecker.new(mrc).execute
        pre.report_to_screen
        QuitOrMain.new
      end
      menu.choice :rebuild_package_data do
        pm = PackageManager.new('data/pkg_list.csv').execute
        pm.report_summary
        QuitOrMain.new
      end
      menu.choice :ingest_monthly_record_set do
        date = ask("What month? Enter YYYYMM or YYYYMMDD\n")
        im = IngestMaster.new(date)
        QuitOrMain.new
      end
      menu.choice :get_error_report do
        @output = []
        @edate = ask("What month? Enter YYYYMM or YYYYMMDD\n")
        @etype = ask("Type (a)dd, (c)hange, (d)elete, or (o)verall\n")
        @rt = :add if @etype == 'a'
        @rt = :change if @etype == 'c'
        @rt = :delete if @etype == 'd'
        if @etype == 'a' or @etype == 'c' or @etype == 'd'
          @eresult = $ecoll.find('date' => @edate, 'rectype' => @rt)
          if @eresult.count > 0
            @eresult.each do |r|
              puts "#{r['errtype']}\t\t#{r['ssid']}"
              @output << [r['date'], r['rectype'], r['errtype'], r['ssid']]
            end
          else
            puts "No errors."
          end
        elsif @etype == 'o'
          @eresult = $ecoll.find('date' => @edate)
          if @eresult.count > 0
            @eresult.each do |r|
              puts "#{r['rectype']}\t#{r['errtype']}\t\t#{r['ssid']}"
              @output << [r['date'], r['rectype'], r['errtype'], r['ssid']]
            end
          else
            puts "No errors."
          end
        else
          puts "Error: invalid type"
          QuitOrMain.new
        end
        output = ask("Output to csv? y/n\n")
        if output == 'y'
          CSV.open("output/#{@edate}#{@etype}errors.csv", 'wb') do |csv|
            @output.each do |r|
              csv << r
            end
          end
        end
        QuitOrMain.new
      end
      menu.choice :clear_states_from_a_date do
        @the_date = ask("Delete states from what date?\n".chomp)
        puts "In db before: #{$scoll.find().count}"
        del = $scoll.remove({'date' => @thedate})
        puts "Deleted: #{del}"
        puts "In db now: #{$scoll.find().count}"
        QuitOrMain.new
      end
      menu.choice :get_marc_records_for_state do
        ssid = ask("Enter ssid\n")
        @sraw = $scoll.find({'ssid' => ssid})
        @states = []
        @sraw.each do |s|
          st = State.new.from_db(s)
          @states << st
        end
        mg = MarcGetter.new(@states).execute
        mg.each do |s|
          puts s[0]
          puts s[1]
          puts "\n\n"
        end
        QuitOrMain.new
      end
      menu.choice :extract_package_marc_from_file do
        path = ask("Enter path to file\n")
        pkg = ask("Enter name of package to extract\n")
        ps = StringScanner.new(path)
        ps.scan /^(.*\/)([^\/]*)(\.mrc)$/
        file = ps[2]
        @recs = []
        MARC::Reader.new(path).each {|rec| @recs << rec if rec.packages.include?(pkg)}
        path = "output/#{file}-#{pkg}.mrc"
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