class Command
  attr_reader :description
  
  def initialize(description)
    @description = description
  end #def initialize(description)
  
  def execute    
  end #def execute
end #class Command

class CompositeCommand < Command
  def initialize
    @commands = []
  end #def initialize
  
  def add_command(cmd)
    @commands << cmd
  end #def add_command(cmd)
  
  def execute
    @commands.each {|cmd| cmd.execute}
  end #def execute
  
  def description
    description = ''
    @commands.each {|cmd| description += cmd.description + "\n"}
    description
  end #def description
end #class CompositeCommand < Command