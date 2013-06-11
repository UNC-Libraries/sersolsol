#(read in mrc file to recs)

punct = []
ts = []
recs.each do |rec|
  t = rec['245']['a']
  ts << t
  t.each_char do |c|
    if c =~ /([a-zA-Z0-9]|\s)/
      next
    else
      punct << c
    end #if c =~ /([a-zA-Z0-9]|\s)/
  end #t.each_char do |c|
end #arecs.each do |rec|

an = {}

punct.uniq.each do |pc|
  titles = []
  ts.each {|t| titles << t if t.include?(pc)}
  an[pc] = titles
end #punct.uniq.each do |pc|

CSV.open("output/punct_analysis.txt", "wb") do |csv|
  an.each_pair do |k, v|
    v.each {|t| csv << [k, t]}
  end #an.each_pair do |k, v|
end
