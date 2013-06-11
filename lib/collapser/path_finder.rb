require 'pathname'

=begin rdoc
Constructs SourcePath objects
*Arguments*
date1 = earlier date
date2 = later date
basepath = base of path to split mrc files created by Record Manager script.

=end
class PathFinder
  attr_reader :paths
  def initialize(date1, date2, basepath)
    @date1 = date1
    @date2 = date2
    @basepath = basepath

    @paths = []
    @allpaths = []
    [@date1, @date2].each {|date| create_paths(date)}
  end

  private

  def create_paths(date)
    %w[add change delete].each do |t|
      #puts "---Processing #{@lib} #{t} path"
      if t == 'change'
        changes = "#{@basepath}#{date[0..3]}/#{date}change.mrc"
        p changes
        @allpaths << Pathname.new(changes)
      else
        add_delete_base = "#{@basepath}#{date[0..3]}/#{date}"
        path = add_delete_base + t + '.mrc'
        p path
        @allpaths << Pathname.new(path)
      end
    end
    @allpaths.each {|path|create_source_path(path, date) if path.exist?}
  end

  def create_source_path(path, date)
    ps = []
    @paths.each {|path| ps << path.code}
    path = path.to_s
#    type_code = 'x'
#    date_code = 'x'
    if date == @date1
      date_code = 'y'
    elsif date == @date2
      date_code = 'z'
    end
    
    if path.include? 'add'
      type_code = 'a'
    elsif path.include? 'change'
      type_code = 'c'
    elsif path.include? 'delete'
      type_code = 'd'
    end
    
    code =  date_code + type_code

    unless ps.include? path
    sp = SourcePath.new(path, code)
    @paths << sp unless @paths.include? sp
    end
  end

end
