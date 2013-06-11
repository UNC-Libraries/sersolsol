require './lib/setup'
require 'marc'

def print_r(text, size=80)
  print "\r#{text.ljust(size)}"
  STDOUT.flush
end

class IngestChanges
  attr_reader :log, :load_as_change, :leftovers_to_load
  def initialize(path, date, type)
    @timed_metric = Hitimes::TimedMetric.new('process one record')
    @duration = Hitimes::Interval.measure do
      @path = path
      @date = date
      @type = type

      @log = {:ch_file_ct => 0,
        :ch_ct => 0,
        :ch_no_load_ct => 0,
        :add_ct => 0,
        :delete_ct => 0,
        :error_ct => 0,
        :errors => {:not_already_seen => []},
        :holdings_change => {:aalload => {:add => [], :delete => []},
          :hsl => {:add => [], :delete => []},
          :law => {:add => [], :delete => []}},
        :leftovers_to_load => {:aalload => {:add => [], :delete => []},
          :hsl => {:add => [], :delete => []},
          :law => {:add => [], :delete => []}}
      }
      puts "Getting MARC records..."
      @recs = []
      MARC::Reader.new(@path.to_s).each {|rec| @recs << rec}
      @log[:ch_file_ct] = @recs.count
      puts "Records to process: #{@log[:ch_file_ct]}"

      @load_as_change = []

      @done_ct = 0
      @step = @log[:ch_file_ct] / (@log[:ch_file_ct] * 0.01)

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
        # (a record must exist to be "changed")
        if @ex == nil
          @log[:errors][:not_already_seen] << rec['001'].value
          @log[:error_ct] += 1
          @state[:loaded?] = false
          @state[:error] = ['Not already seen']
          $scoll.insert(@state)
        else # @ex != nil
          @state[:libs] = @state.libs

          if @state.loaded?
            # ...if the new state is to be loaded
            @state[:loaded?] = true

            if @ex.loaded? # and new state loaded
              # if previous state was also loaded
              # load as change (
              @load_as_change << rec
              @log[:ch_ct] += 1
              #puts @state[:ssid]
              hold = find_holdings_changes(@state[:libs], @ex[:libs])
              #puts "STATE: #{@state[:libs]}"
              #puts "EX: #{@ex[:libs]}"
              #p hold
              if hold[:add]
                hold[:add].each do |lib|
                  if lib == :aalload or lib == :hsl or lib == :law
                    @log[:holdings_change][lib][:add] << @state
                  end
                end
              end
              if hold[:delete]
                hold[:delete].each do |lib|
                  if lib == :aalload or lib == :hsl or lib == :law
                    @log[:holdings_change][lib][:delete] << @state
                  end
                end
              end
            else # @ex not loaded and new state loaded
              # if previous state was not loaded
              hold = find_holdings_changes(@state[:libs], @ex[:libs])
              adds = hold[:add].select {|lib| lib == :aalload or lib == :hsl or lib == :law}
              adds.each do |lib|
                @log[:leftovers_to_load][lib][:add] << rec
              end
              @log[:add_ct] += 1
            end
              
          else # and new state not to be loaded
            # if the new state is NOT to be loaded
            @state[:loaded?] = false
              
            if @ex.loaded? # and new state not to be loaded
              # if the previous state WAS loaded
              hold = find_holdings_changes(@state[:libs], @ex[:libs])
              deletes = hold[:delete].select {|lib| lib == :aalload or lib == :hsl or lib == :law}
              deletes.each do |lib|
                @log[:leftovers_to_load][lib][:delete] << rec
              end
              @log[:delete_ct] += 1
            else #@ex not loaded and new state not loaded
              # if the previous state was not loaded
              @log[:ch_no_load_ct] += 1
            end
          end
          # ... for all where there is not already a state for the record in db
          $scoll.insert(@state)
          end
          # progress display
          @done_ct += 1
          if @done_ct % @step == 0
            print_r(
              "%d of %d (%d%%)" %
              [@done_ct, @log[:ch_file_ct], (@done_ct.to_f/@log[:ch_file_ct] * 100)]
            )
          @timed_metric.stop
        end


      end
      puts "\n\n"
      puts "Changes to load: #{@log[:ch_ct]}"
      puts "To NOT load: #{@log[:ch_no_load_ct]}"
      puts "Adds: #{@log[:add_ct]}"
      puts "Deletes: #{@log[:delete_ct]}"
      puts "Errors: #{@log[:error_ct]}"

      if @log[:ch_ct] + @log[:ch_no_load_ct] + @log[:error_ct] + @log[:add_ct] + @log[:delete_ct]!= @log[:ch_file_ct]
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

  def find_holdings_changes(statelibs, exlibs)
    result = {}
    adds = statelibs - exlibs
    result[:add] = adds if adds.size > 0
    deletes = exlibs - statelibs
    result[:delete] = deletes if deletes.size > 0
    result
  end
end
