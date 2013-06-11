require 'marc'
require 'marc_extended'

class SourcePath
  attr_reader :path, :code
  attr_accessor :idos, :aids, :cids, :dids
  def initialize(path, code)
    @path = path
    @code = code
    @idos = []
    @aids = []
    @cids = []
    @dids = []
  end

  def gather_ids
    ind = 0
    recs = []
    MARC::Reader.new(path).each {|rec| recs << rec}
    recs.each do |rec|
      ssid = rec._001
      i = IdObject.new(ssid, @code, ind, path)
      ind += 1
      @idos << i
    end
  end
end
