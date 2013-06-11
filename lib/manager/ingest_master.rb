require './lib/setup'
require 'strscan'
require 'pathname'

class IngestMaster
  attr_accessor :add_log, :change_log, :delete_log, :deletes_to_write
  def initialize(date)
    puts "\n\nParsing date..."
    unless date =~ /^\d{6}(?:\d{2})?$/
      puts "Cannot understand date you entered."
      puts "Date must be all digits, in the form: YYYYMM or YYYYMMDD."
      exit
    end

    @year = ''
    @month = ''
    @day = ''
    @date = ''
    parse_date(date)

    puts "\n\nFinding files..."
    @adds = get_file('add')
    @changes = get_file('change')
    @deletes = get_file('delete')
    [@adds, @changes, @deletes].each {|f| p f}

    @adds_to_write = {:aalload => [], :hsl => [], :law => []}
    @changes_to_write = []
    @deletes_to_write = {:aalload => [], :hsl => [], :law => []}

    if @adds
      puts "\n\nCalling Added Record Ingester..."
      @a = IngestAdds.new(@adds, @date, :add)
      @adds_to_write = @a.to_load  if @a.to_load
      @add_log = @a.log
      @add_log[:errors].each_pair do |type, err|
        if err.count > 0
          @the_type = type
          err.each do |err|
            e = {:date => @date, :rectype => :add, :errtype => @the_type, :ssid => err}
            $ecoll.insert(e)
          end
        end
      end
    end

    if @deletes
      puts "\n\nCalling Deleted Record Ingester..."
      @d = IngestDeletes.new(@deletes, @date, :delete)
      @deletes_to_write = @d.to_load if @d.to_load
      @delete_log = @d.log
    end

    if @changes
      puts "\n\nCalling Changed Record Ingester..."
      @c = IngestChanges.new(@changes, @date, :change)
      if @c.leftovers_to_load
        @c.leftovers_to_load.each_pair do |lib, types|
          @lib_code = lib
          types.each_pair do |t, recs|
            if t == :add
              recs.each do |rec|
                @adds_to_write[@lib_code] << rec
              end
            elsif t == :delete
              recs.each do |rec|
                @deletes_to_write[@lib_code] << rec
              end
            end
          end
        end
      end
      @changes_to_write = @c.load_as_change if @c.load_as_change
      @change_log = @c.log
    end

    write_adds(@adds_to_write) if @adds_to_write.size > 0
    write_deletes(@deletes_to_write) if @deletes_to_write.size > 0
    write_changes(@changes_to_write) if @changes_to_write.size > 0
  end

  def parse_date(date)
    s = StringScanner.new(date)
    s.scan /(\d{4})(\d{2})/
    @year = s[1]
    @month = s[2]
    if s.post_match == ''
      @day = '01'
    else
      @day = s.post_match
    end
    @date = @year + @month + @day
    puts @date
  end

  def get_file(type)
    pathstring = "#{$marc_root}/orig/#{@year}/#{@date}#{type}.mrc"
    puts pathstring
    path = Pathname.new(pathstring)
    
    if path.exist?
      return path
    else
      return nil
    end
  end

  def write_adds(adds)
    puts "Writing adds..."
    adds.each_pair do |lib, recs|
      if recs.count > 0
        puts "Writing #{recs.count} records to #{lib.to_s} add file."
        path = "output/#{lib.to_s}#{@date}add.mrc"
        writer = MARC::Writer.new(path)
      
        recs.each do |rec|
          writer.write(rec)
        end
        writer.close
      end
    end
  end

  def write_changes(changes)
    puts "Writing changes..."
    path = "output/#{@date}changes.mrc"
    @writer = MARC::Writer.new(path)
    changes.each {|rec| @writer.write(rec)}
    @writer.close
  end

  def write_deletes(deletes)
    puts "Writing deletes..."
    deletes.each_pair do |lib, recs|
      if recs.count > 0
        puts "Writing #{recs.count} records to #{lib.to_s} delete file."
        path = "output/#{lib.to_s}#{@date}delete.mrc"
        writer = MARC::Writer.new(path)
      
        recs.each do |rec|
          writer.write(rec)
        end
        writer.close
      end
    end
  end
end


