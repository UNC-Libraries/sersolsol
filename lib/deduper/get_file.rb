require 'csv'

#class GetFile
#  attr_reader :csv, :headers
#  def initialize(path)
#    @csv = CSV.read(path, :headers => true)
#    @headers = csv.headers
#  end
#end

class GetFile
  attr_reader :csv, :headers
  def initialize(path)
    @csv = CSV.read(path)
    @headers = @csv.shift
  end
end