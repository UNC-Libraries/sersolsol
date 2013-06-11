require './lib/setup'
require 'marc'

def print_r(text, size=80)
  print "\r#{text.ljust(size)}"
  STDOUT.flush
end

class IngestDeletes
  attr_reader :log, :to_load
  def initialize(path, date, type)
    @timed_metric = Hitimes::TimedMetric.new('process one record')
    @duration = Hitimes::Interval.measure do
      @path = path
      @date = date
      @type = type

      @log = {:del_file_ct => 0, :del_ct => 0, :del_no_load_ct => 0,
        :error_ct => 0, :errors => {:not_already_seen => []}}
      puts "Getting MARC records..."
      @recs = []
      MARC::Reader.new(@path.to_s).each {|rec| @recs << rec}
      @log[:del_file_ct] = @recs.count
      puts "Records to process: #{@log[:del_file_ct]}"

      @to_load = {:aalload => [], :hsl => [], :law => []}

      @done_ct = 0
      @step = @log[:del_file_ct] / (@log[:del_file_ct] * 0.01)

      @recs.each do |rec|
        @timed_metric.start
        @state = State.new.from_marc(rec, @date, @type)
        found = @state.find_in_db.first
        if found
          @ex = State.new.from_db(found)
        else
          @ex = nil
        end

        # if there is NOT already a state for the record in the db
        # (a record must exist to be deleted)
        if @ex == nil
          @log[:errors][:not_already_seen] << rec['001'].value
          @log[:error_ct] += 1
          @state[:loaded?] = false
          @state[:error] = ['Not already seen']
          $scoll.insert(@state)
        else # if @ex != nil
          @state[:libs] = @state.libs

          if @ex[:loaded?] = true
            #write to delete file for ex's active libraries
            #set this state also to loaded
            @state[:loaded?] = true
            @log[:del_ct] += 1
            libs = @ex[:libs].select {|n| n == :aalload or n == :hsl or n == :law}
            
            if libs.include? :hsl or libs.include? :law
              @to_load[:hsl] << rec if libs.include? :hsl
              @to_load[:law] << rec if libs.include? :law
            else
              @to_load[:aalload] << rec if libs.include? :aalload  
            end

          else # if @ex is not loaded
            @state[:loaded?] = false
            @log[:del_no_load_ct] += 1
          end
          # ... for all where there is not already a state for the record in db
          

          $scoll.insert(@state)

          # progress display
          @done_ct += 1
          if @done_ct % @step == 0
            print_r(
              "%d of %d (%d%%)" %
              [@done_ct, @log[:del_file_ct], (@done_ct.to_f/@log[:del_file_ct] * 100)]
            )
          end
          @timed_metric.stop
        end


      end
      puts "\n\n"
      puts "Deletes to load: #{@log[:del_ct]}"
      puts "To NOT load: #{@log[:del_no_load_ct]}"
      puts "Errors: #{@log[:error_ct]}"

      if @log[:del_ct] + @log[:del_no_load_ct] + @log[:error_ct] != @log[:del_file_ct]
        puts "Warning! Number off somewhere..."
      end
    end

    puts "Total time to process adds: #{@duration} seconds."
    puts "Mean #{@timed_metric.mean}"
    puts "Max #{@timed_metric.max}"
    puts "Min #{@timed_metric.min}"
    puts "Stddev #{@timed_metric.stddev}"
    puts "Rate #{@timed_metric.rate}"

    return self
  end
end