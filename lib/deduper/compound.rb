# Compound element for use in comparisons.
# Carries metadata about the combined data that will later be compared,
#   so the application can construct the complex strings for comparison.
class Compound
  # Each component is an Element or another Compound
  attr_accessor :component1, :component2, :name, :ind, :displaynum
  def initialize(component1, component2, rk)
    @rk = rk
    @component1 = component1
    @component2 = component2
    @name = "(" + @component1.name + " + " + @component2.name + ")"
    @ind = [@component1.ind, @component2.ind].flatten
    @displaynum = mkdisplaynum
  end

  private
  def mkdisplaynum
    num = @rk.materials.size + 1
    num.to_s
  end
end
