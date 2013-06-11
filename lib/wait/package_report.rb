require 'setup'

all = Package.all(:order => "name ASC")

all.each do |pkg|
  claims = pkg.claims
  puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
  puts "#{pkg.name}"
  puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
  claims.each do |c|
    puts "LIBRARY: #{c.library.code}\nIN: #{c[:in]}\nOUT: #{c[:out]}\n\n"
  end #claims.each do |c|
end #all.each do |pkg|