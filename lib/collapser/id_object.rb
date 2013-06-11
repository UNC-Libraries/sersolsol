class IdObject
  attr_reader :ssid, :code, :index, :path
  attr_accessor :keep, :type
  def initialize(ssid, code, index, path)
    @ssid = ssid
    @code = code
    @path = path
    @index = index
    @keep = ''
    @type = ''
  end

  

end
