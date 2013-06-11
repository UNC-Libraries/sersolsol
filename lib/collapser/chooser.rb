=begin rdoc
Selects which record to use and tells which file it should be put it
*Arguments*
[idos] array of IdObjects for a single ssid
*Returns*
Array with the following structure:
[IdObject, type]
=end
class Chooser
  attr_reader :winner, :loser
  def initialize(idos)
    if idos.count == 1
      @loser = 0
      if idos[0].code.include? 'a'
        @winner = [idos[0], :add]
      elsif idos[0].code.include? 'c'
        @winner = [idos[0], :change]
      elsif idos[0].code.include? 'd'
        @winner = [idos[0], :delete]
      end

    else
      @loser =  1
      ya = idos.select {|i| i.code.include? 'y'}
      za = idos.select {|i| i.code.include? 'y'}
      y = ya[0].code[1]
      z = za[0].code[1]

      if y == 'a'
        @winner = [za[0], :add]    if z == 'a'
        @winner = [za[0], :change] if z == 'c'
        #if z == 'd', ignore both
      elsif y == 'c'
        @winner = [za[0], :change] if z == 'a'
        @winner = [za[0], :change] if z == 'c'
        @winner = [za[0], :delete] if z == 'd'
      elsif y == 'd'
        @winner = [za[0], :change] if z == 'a'
        @winner = [za[0], :change] if z == 'c'
        @winner = [za[0], :delete] if z == 'd'
      end
    end

    return @winner

  end
end
