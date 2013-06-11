class ComparisonCreator
  def initialize(record_keeper)
    section = "set up a comparison"
    desc = "Configure what will be compared to what.\nYou can compare a field to itself. Just enter the same field twice.\nYou will assign a weight to each comparison. More means that a match on that comparison is more indicative of a true duplicate."
    ConsoleHeading.new(section, desc)

    @rk = record_keeper

    initial_display

    PostCreateComparisonMenu.new(@rk)
  end
end

private

def initial_display
  if @rk.comparisons.size == 0
    @rk.list_materials
    puts "\n\nWhat next?"
    choose do |menu|
      menu.prompt = "..."
      menu.choice :create_a_new_comparison do create_comparison end
      menu.choice :go_back_to_main_menu do MainMenu.new(@rk) end
    end
  else
    puts "\n\nWhat do you want to see?"
    choose do |menu|
      menu.prompt = "Show me..."
      menu.choice :existing_comparable_elements do @rk.list_materials end
      menu.choice :existing_comparisons do @rk.list_comparisons end
      menu.choice :just_create_a_new_comparison do create_comparison end
    end
  end
end

def create_comparison
  c1 = ask("Enter number of first thing to compare.")
  p c1
  c1o = @rk.lookup_material_by_display_number(c1.chomp)
  p c1o
  c2 = ask("Enter number of thing to compare with #{c1o.name}?")
  c2o = @rk.lookup_material_by_display_number(c2)
  p c2
  p c2o
  weight = ask("Give this comparison a numeric weight. Whole numbers only (no decimals). Bigger = better.")
  c = Comparison.new(c1o, c2o, weight)
  @rk.comparisons << c
  puts c.describe
end
