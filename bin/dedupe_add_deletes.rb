require 'rubygems'
require 'string'
require 'marc'
require 'marc_extended'
require 'marc_sersol'
require 'csv'
require 'ostruct'
require 'facets'
require 'trie'
require 'amatch'
require 'highline/import'
include Amatch

# configure cutoff scores
tp_match_cutoff = 0.75

match_hash = {}

#new = ARGV[0]
#delete = ARGV[1]

add = "data/201011_s_add.mrc"
arecs = []
MARC::Reader.new(add).each {|rec| arecs << rec}

del = "data/201011_s_delete.mrc"
drecs = []
MARC::Reader.new(del).each {|rec| drecs << rec}

def splitter(tosplit, splitstring)
  if tosplit.match(splitstring)
    split = tosplit.split(splitstring, 2)
  end #if tosplit.include?(splitstring)
end #def splitter(string)

def make_ssitems(rec)
  i = OpenStruct.new

  # get ssj number
  i.ssid = rec._001

  # get title and normalize (lowercase, clean spaces, quotes, &s)
  i._245a = rec['245']['a'].downcase.squish
  i._245a.gsub!(/ & /, ' and ')
  i._245a.gsub!(/&/, ' and ')
  i._245a.gsub!(/["']/, '')

  # get uniform title
  i.ut = rec['130'].to_s.gsub(/ \(Online\)/, '').squish

  # get issn
  if rec['022']
    if rec['022']['a']
      i.issn = rec['022']['a']
      #      puts i.issn
    end
  end

  # get provider/package(s)
  i.provider = rec.packages

  # copy 245a to i.tp so we can work on i.tp while keeping i._245a intact
  i.tp = i._245a.omitInitialArticle.squish

  #yank parentheticals out
  if i.tp.match(/\(.*\)/)
    i.paren = i.tp.slice(/\([^)]*\)/).gsub(/\(|\)/, '').squish
    i.tp.gsub!(/\([^)]*\)/, '')
    #        puts "Split out parenthetical..."
    #        puts "Remaining title: #{i.tp}"
    #        puts "Parenthetical: #{i.paren}"
    #        puts "\n\n"
  end #if i.tp.include?()

  #yank bracketed out
  if i.tp.match(/\[.*\]/)
    i.bracketed = i.tp.slice(/\[[^\]]*\]/).sub(/\[|\]/,'').squish
    i.tp.gsub!(/\[[^\]]*\]/, '').squish
    #        puts "Split out bracketed..."
    #        puts "Remaining title: #{i.tp}"
    #        puts "Parenthetical: #{i.bracketed}"
    #        puts "\n\n"
  end #if i.tp.include?()

  #split out statement of responsibility
  sora = splitter(i.tp, " / ")
  if sora
    i.tp = sora[0].squish
    i.sor = sora[1].squish
    #        puts "Split out statement of responsibility..."
    #        puts "Remaining title: #{i.tp}"
    #        puts "Statement of resp.: #{i.sor}"
    #        puts "\n\n"
  end

  #split out alternate title
  alts = splitter(i.tp, /[,;] or, /)
  if alts
    i.tp = alts[0].squish
    i.alt = alts[1].omitInitialArticle.squish
    #        puts "Split out alternate title"
    #        puts "Remaining title: #{i.tp}"
    #        puts "Alternate title: #{i.alt}"
    #        puts "\n\n"
  end


  #split out other title info
  otis = splitter(i.tp, / - | ?: |\. - ?/)
  if otis
    i.tp = otis[0].squish
    i.oti = otis[1].omitInitialArticle.squish
    #        puts "Split out other title info"
    #       puts "Remaining title: #{i.tp}"
    #        puts "Other title info: #{i.oti}"
    #        puts "\n\n"
  else
    #split out other title info (2nd pass)
    otis = splitter(i.tp, / ?; /)
    if otis
      i.tp = otis[0].squish
      i.oti = otis[1].omitInitialArticle.squish
      #      puts "Split out other title info"
      #      puts "Remaining title: #{i.tp}"
      #      puts "Other title info: #{i.oti}"
      #      puts "\n\n"
    end
  end

  return i
end #def make_ssitems(rec, type)

# create an array of ssitems, one for each added record
adds = []
arecs.each {|r| adds << make_ssitems(r)}

# create an array of ssitems, one for each deleted record
deletes = []
drecs.each {|r| deletes << make_ssitems(r)}

# create a trie structure and insert all title propers from added records
# key = title proper, value = the whole new ssitem
addtps = Trie.new
adds.each do |a|
  addtps.insert(a.tp, a)
end #adds.each do |a|

#create hash to hold match scores
matchscores = {}

# for each deleted record,
deletes.each do |d|
  # append a tp_match property to deleted ssitem
  d.tp_match = []

  # copy the real tp to a new variable to mess with it.
  tp = d.tp

  # set counter to check whether there are any matches
  a_match = 0

  # m is any added tp that exactly matches the deleted tp
  # returns array of added ssitem(s) w/matching tp
  m = addtps[tp]

  # sends exact matches to matchscores
  m.each do |e|
    pair = [d.ssid, e.ssid].sort
    matchscores[pair] = {"delete" => {"ssid" => d.ssid, "str" => d.tp},
      "add" => {"ssid" => e.ssid, "str" => e.tp},
      "score" => 1.0
    }
  end #m.each do |e|

  # sets counter to > 0 if there are any exact matches
  a_match = m.size

  # if there are no exact matches
  if a_match == 0

    # as long as there are no partial matches and the tp string has at least
    # 2 characters, chop off the last letter of the tp string and search the trie
    # again.
    while tp.length > 2 && addtps.find_prefix(tp).size == 0
      tp = tp.chop
      #when one or more partial matches have been found, end.
    end

    # pop the entire string from added tps that partially matches delete tp
    # into array called partialmatches
    partialmatches = []
    addtps.find_prefix(tp).keys.each {|k| partialmatches << tp + k.join('')}

    # if there are any partial matches
    if partialmatches.size > 0

      # calculate match score for each and send to array of match scores
      # match score is JaroWinkler similarity score times pair distance similarity
      partialmatches.each do |e|
        news = addtps[e]
        origpd = PairDistance.new(d.tp)
        origjw = JaroWinkler.new(d.tp)
        pdscore = origpd.match(e)
        jwscore = origjw.match(e)

        news.each do |ne|
          pair = [d.ssid, ne.ssid].sort
          matchscores[pair] = {"delete" => {"ssid" => d.ssid, "str" => d.tp},
                               "add" => {"ssid" => ne.ssid, "str" => ne.tp},
                               "score" => pdscore * jwscore
                               }
        end #news.each do |ne|
      end #if partialmatches.size > 0
    end #if a_match == 0
  end #deletes.each do |d|

  tp_matches = matchscores.select {|k, v| s[4] > tp_match_cutoff}

  tp_matches.each do |m|
    pair = [m[0], m[2]].sort
    if match_hash.has_key?(pair)
      val = match_hash[pair]
      val["tp-tp"] = {"strings" => m[]}
    end #if match_has.has_key?(pair)
  end #tp_matches.each do |m|

  CSV.open("output/match_analysis.txt", "wb") do |csv|
    csv << ['deleted id', 'deleted tp', 'added id', 'added tp', 'match score']
    matches.each {|r| csv << r}
  end #csv
