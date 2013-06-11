require './lib/manager/command'
require 'marc'
require 'marc_sersol'
require 'strscan'
require 'trie'

=begin rdoc
Is called, given an argument: array of state objects
Returns an array like:
   [[state, marc], [state, marc]]

* create a hash grouping state objects by state[:date] + state[:type}:
   {'20100601add' => [states from that file], '20100701add.mrc' => [states from there]}
* for each pair from this hash:
** construct path to MARC file using key
** read in that MARC file
** construct trie of records in MARC file: keys = ssid, values = MARC records
** for each element in value:
*** find state[:ssid] in trie and push it and the record it retrieves to result
array.
* return result array 
=end

class MarcGetter < Command
  attr_reader :states_and_recs
  def initialize(state_array)
    @states = state_array
    @state_hash = {}
    @states_and_recs = []
    
    
  end

  def execute
    populate_state_hash(@states)
    @state_hash.each_pair {|filename, states| arborist(filename, states)}
     return @states_and_recs
  end

  def arborist(filename, states)
    the_path = construct_path(filename)
    @recs = []
    MARC::Reader.new(the_path).each {|rec| @recs << rec}
    @oak = Trie.new
    foliate_trie(@oak, @recs)
    states.each do |state|
      lookup = state[:ssid]
      leaf = @oak.find(lookup).values[0]
      @states_and_recs << [state, leaf]
    end
  end
  
  def foliate_trie(tree, records)
    records.each do |rec|
      @oak.insert(rec.localize001, rec)
    end
  end

  def construct_path(filename)
    fn = StringScanner.new(filename)
    fn.scan /(\d{4})(.*)/
    year = fn[1]
    return "#{$marc_root}/orig/#{year}/#{filename}"
  end
  def populate_state_hash(states)
    until states.count == 0 do
      state = states.shift
      fname = state[:date].to_s + state[:type].to_s + '.mrc'
      if @state_hash.has_key? fname
        @state_hash[fname] << state
      else
        @state_hash[fname] = [state]
      end
    end
    return @state_hash
  end
end
