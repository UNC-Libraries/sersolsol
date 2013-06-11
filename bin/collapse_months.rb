# Combines two months of sersol loads into one set to distribute/load
# Call with two arguments: the two dates to collapse.
# Use the whole date as in the file names:
#   ruby bin/collapser.rb  20101201 20110101
require './lib/collapser'
require 'marc'

@basepath = 'data/ssmrc/orig/'

@date1 = ARGV[0]
@date2 = ARGV[1]


# get unique pathnames we will be dealing with
paths = []
pths = []

pf = PathFinder.new(@date1, @date2, @basepath)
  nps = pf.paths
  nps.each do |np|
    paths << np unless pths.include? np.path
    pths << np.path
  end

bct = 0
paths.each {|path| p path}
paths.each {|path| path.gather_ids}
paths.each {|path| puts path.idos.count.to_s  + "\t recs in: (#{path.code}) " + path.path; bct += path.idos.count}
puts "Read in: #{bct}"

#populate idhash
idhash = {}

paths.each do |path|
  path.idos.each do |i|
    if idhash.has_key? i.ssid
      idhash[i.ssid] << i
    else
      idhash[i.ssid] = [i]
    end
  end
end

ct = 0
idhash.each_value {|v| ct += 1 if v.count > 1}

losers = 0
idhash.each_value do |idos|
  #puts "\n\n#{idos.inspect}"
  c = Chooser.new(idos)
  i = c.winner
  losers += 1 if c.loser == 1
  ido = i[0]
  #p ido
  path = ido.path
  type = i[1]
  sp = paths.select {|spath| spath.path == path}
  sp[0].aids << ido if type == :add
  sp[0].cids << ido if type == :change
  sp[0].dids << ido if type == :delete
end
  
to_write = {:adds => [], :changes => [], :deletes => []}

paths.each do |sp|  
  recs = []
  MARC::Reader.new(sp.path).each {|rec| recs << rec}
  
  sp.aids.each {|i| to_write[:adds] << recs[i.index]} if sp.aids.count > 0
  sp.cids.each {|i| to_write[:changes] << recs[i.index]} if sp.cids.count > 0
  sp.dids.each {|i| to_write[:deletes] << recs[i.index]} if sp.dids.count > 0
end

total = 0

to_write.each_pair do |type, recs|
    if recs.count > 0
      filename = "COLLAPSED_#{type}"
      writer = MARC::Writer.new("output/#{filename}.mrc")
      recs.each {|rec| writer.write rec}
      total += recs.count
      writer.close
    end  
  end

  puts "Written out: #{total}"
  puts "Discarded: #{losers}"
  puts "Total processed: #{total + losers}"