BEGIN {puts "Starting up..."}

require 'setup'
require 'timer'
require 'fastercsv'
require 'facets'

timer = Timer.new
timer.time("Done!") do
  
  
  the_file = ARGV[0]
  
  puts "Reading file."
  
  recs = []
  MARC::Reader.new(the_file).each {|rec| recs << rec}
  
  
  index = 0
  @record_count = recs.size
  
  
  pkg_stats = [['recs', 'brief', 'briefp', 'full', 'fullp', 'mep', 'sorp', 
  'auth find', 'auth_find_p', 'pub', 'pubp', 'date', 'datep', 'ser', 'serp', 'pae', 'paep', 
  'paes', 'avg paes', 'sh', 'shp', 'shs', 'avg shs', 'ush', 'ushp', 'ushs', 'avg ushs']]
  
  briefs = 0
  full = 0
  main_entry_recs = 0
  sor_recs = 0
  author_findable_recs = 0
  pub_name_recs = 0
  pub_date_recs = 0
  series_recs = 0    
  person_ae_recs = 0
  person_aes = 0
  sh_recs = 0
  shs = 0
  ush_recs = 0
  ushs = 0
  
  puts "Calculating stats."    
  recs.each do |r|
    briefs += 1 if r.ssid =~ /ss[ei]b/
    full += 1 if r.ssid =~ /ss[ej]\d/
    
    me = r.main_entry?
    sor = r['245']['c']
    main_entry_recs += 1 if me
    sor_recs += 1 if sor
    author_findable_recs += 1 if me || sor
    
    pub_name_recs += 1 if r['260']['b'] && r['260']['b'].match(/s\. ?n\./) == false
    pub_date_recs += 1 if r['260']['c']
    
    series_recs += 1 if r['440'] || r['490'] || r['800'] || r['830']
    
    person_ae_recs += 1 if r.count_paes > 0
    person_aes += r.count_paes
    
    sh_recs += 1 if r.count_controlled_shs > 0
    shs += r.count_controlled_shs
    
    ush_recs += 1 if r.count_uncontrolled_shs > 0
    ushs += r.count_uncontrolled_shs
    
    index = index += 1
    
    def print_r(text, size=80)
      print "\r#{text.ljust(size)}"
      STDOUT.flush
    end
    print_r(
        "%d of %d (%d%%)" %
    [index, @record_count, (index.to_f/@record_count * 100)]
    )
    
  end #recs.each do |r|
  puts "\n"
  
  #    pkg_stats = [['name', 'recs', 'brief', 'briefp', 'full', 'fullp', 'me', 'mep', 'sor', 'sorp', 
  #  'auth find', 'auth_find_p', 'pub', 'pubp', 'date', 'datep', 'ser', 'serp', 'pae', 'paep', 
  #  'paes', 'avg paes', 'sh', 'shp', 'shs', 'avg shs', 'ush', 'ushp', 'ushs', 'avg ushs']]
  
  
  
  puts "Preparing output."
  if @record_count > 0
    pkg_stats.push([@record_count, 
                   briefs, briefs / @record_count.to_f, 
                   full, full / @record_count.to_f,
                   main_entry_recs, main_entry_recs / @record_count.to_f, 
                   sor_recs, sor_recs / @record_count.to_f, 
                   author_findable_recs, author_findable_recs / @record_count.to_f, 
                   pub_name_recs, pub_name_recs / @record_count.to_f, 
                   pub_date_recs, pub_date_recs / @record_count.to_f, 
                   series_recs, series_recs / @record_count.to_f, 
                   person_ae_recs, person_ae_recs / @record_count.to_f, 
                   person_aes, person_aes / @record_count.to_f, 
                   sh_recs, sh_recs / @record_count.to_f, 
                   shs, shs / @record_count.to_f, 
                   ush_recs, ush_recs / @record_count.to_f, 
                   ushs, ushs / @record_count.to_f])
  end #if @record_count > 0
  
  statsheet = FasterCSV.open('output/pkg_stats.csv', "w") do |csv|
    pkg_stats.each do |r|
      csv << r
    end #pkg_stats.each do |r|
  end #statsheet = FasterCSV.open('output/pkg_stats.csv', "w") do |csv|
  
  def percent(num)
    if num != 0
    raw = num / @record_count.to_f
    pc = raw * 100
    return pc.round_to(0.1)
  else
    return 0
    end
  end #def percent
  
  def report(label, var)
    puts "#{var} (#{percent(var)})%\t #{label}"
  end #def report(var)
  
  puts "Records: #{@record_count}" 
  report('Brief records', briefs)
  report('Full records', full)
report('Main entry', main_entry_recs)
report('Statement of resp.', sor_recs)
report('Findable by author', author_findable_recs)
report('Publisher name', pub_name_recs)
report('Publication date', pub_date_recs)
report('Series', series_recs)
report('Person added entries', person_ae_recs)
puts "#{person_aes}\t\tNumber of person added entries"
report('Controlled subjects', sh_recs)
puts "#{shs}\t\tNumber of controlled subjects"
report('Uncontrolled subjects', ush_recs)
puts "#{ushs}\t\tNumber of uncontrolled subjects"
  
  
end #timer