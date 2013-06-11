# To change this template, choose Tools | Templates
# and open the template in the editor.

class Comparison
  attr_accessor :c1, :c2, :weight
  def initialize(c1, c2, weight)
    @c1 = c1
    @c2 = c2
    @weight = weight
  end

  def describe
    str = "[#{@c1.name} vs. #{@c2.name}]\tx #{@weight}"
  end
end
