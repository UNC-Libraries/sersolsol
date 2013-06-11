require './lib/setup'
require 'marc'

def print_r(text, size=80)
  print "\r#{text.ljust(size)}"
  STDOUT.flush
end

class IngestAdds
  attr_reader :log, :to_load
  def initialize(path, date, type)
    @timed_metric = Hitimes::TimedMetric.new('process one record')
    @duration = Hitimes::Interval.measure do
      @path = path
      @date = date
      @type = type

      @log = {:add_file_ct => 0, :add_ct => 0, :add_no_load_ct => 0,
        :error_ct => 0, :errors => {:already_loaded => []}}
      puts "Getting MARC records..."
      @recs = []
      MARC::Reader.new(@path.to_s).each {|rec| @recs << rec}
      @log[:add_file_ct] = @recs.count
      puts "Records to process: #{@log[:add_file_ct]}"
    
      @to_load = {:aalload => [], :hsl => [], :law => []}

      @done_ct = 0
      @step = @log[:add_file_ct] / (@log[:add_file_ct] * 0.01)

      @recs.each do |rec|
        @timed_metric.start
        @state = State.new.from_marc(rec, @date, @type)

        @ex = @state.find_in_db.first

        # if there is already a state for the record in the db
        if @ex != nil and @ex['type'] != :delete
          @log[:errors][:already_loaded] << rec['001'].value
          @log[:error_ct] += 1
          @state[:loaded?] = false
          @state[:error] = ['Already loaded & loaded state is not a delete.']
          $scoll.insert(@state)
        else

          @state[:libs] = @state.libs
          
          if @state.loaded?
            # ...and state should be loaded
            @state[:loaded?] = true
            @log[:add_ct] += 1
            @state[:libs].each do |lib|
              if lib == :aalload or lib == :hsl or lib == :law
                @to_load[lib] << rec
              end
            end
          else
            # ...and state should NOT be loaded
            @state[:loaded?] = false
            @log[:add_no_load_ct] += 1
          
            # ... for all where there is not already a state for the record in db
          end
          $scoll.insert(@state)
        end

        # progress display
        @done_ct += 1
        if @done_ct % @step == 0
          print_r(
            "%d of %d (%d%%)" %
            [@done_ct, @log[:add_file_ct], (@done_ct.to_f/@log[:add_file_ct] * 100)]
          )
        end
        @timed_metric.stop
      end
      puts "\n\n"
      puts "To load: #{@log[:add_ct]}"
      puts "To NOT load: #{@log[:add_no_load_ct]}"
      puts "Errors: #{@log[:error_ct]}"
      if @log[:add_ct] + @log[:add_no_load_ct] + @log[:error_ct] != @log[:add_file_ct]
        puts "Warning! Number off somewhere..."
      end
    end
    
    puts "Total time to process adds: #{@duration} seconds."
    puts "Mean #{@timed_metric.mean}"
    puts "Max #{@timed_metric.max}"
    puts "Min #{@timed_metric.min}"
    puts "Stddev #{@timed_metric.stddev}"
    puts "Rate #{@timed_metric.rate}"

  end
end


