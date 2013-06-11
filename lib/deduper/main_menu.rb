# To change this template, choose Tools | Templates
# and open the template in the editor.

class MainMenu
  def initialize(record_keeper)
    rk = record_keeper

    choose do |menu|
      puts "\n\n"
      puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
      puts "main menu".upcase
      puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
      menu.prompt = "Choose an action..."

      menu.choice :show_comparable_elements do
        section = "show comparable elements"
        desc = "Each of the fields in the list can be compared against itself or any other field in the list."
        ConsoleHeading.new(section, desc)
        rk.list_materials
        PostShowAllElementsMenu.new(rk)
      end

      menu.choice :create_compound_comparable_element do
        CompoundCreator.new(rk)
      end

      #todo remove an element

      menu.choice :set_up_comparisons do
        ComparisonCreator.new(rk)
      end

      menu.choice :run_comparisons do
        ComparisonRunner.new(rk)
      end

      menu.choice :show_data do
        $data.csv.each {|r| puts r}
      end
      menu.choice :quit do exit end

    end
  end
end
