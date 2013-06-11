require './lib/setup'

class PackageScopeCalculator < Command
  def initialize
    @rehydrated = []
    $pcoll.find.each {|pkg| @rehydrated << Package.new.from_db(pkg)}
    @result = {}
  end

  def execute
  @rehydrated.each do |pkg|
    a = pkg.active_libs

    if a.count > 0
      pkg[:activelibs] = a
      pkg[:loadlibs] = a.select {|e| e == :aalload or e == :hsl or e == :law}
      pkg[:loaded?] = true if pkg[:loadlibs].count > 0
    else
      pkg[:loaded?] = false
    end
    pkg.save
#    puts "\n\nPackage: #{pkg[:names][0]}"
#    puts "Active libs: #{pkg[:activelibs].join(', ')}"
#    puts "Loaded libs: #{pkg[:loadlibs].join(', ')}"
#    puts "Loaded?: #{pkg[:loaded?].to_s}"
  end

end
end
