class Squisher
  attr_accessor
  def initialize(date1, date2, basepath, lib)
    @date1 = date1
    @date2 = date2
    @basepath = basepath
    @lib = lib

    paths = []
    puts "Creating paths..."
    PathFinder.new(@date1, @date2, @basepath, @lib).paths.each {|p| paths << p}
    puts paths
  end
end
