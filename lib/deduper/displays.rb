class ConsoleHeading
  def initialize(section, desc)
    puts "\n-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
    puts section.upcase
    puts desc
    puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
  end
end

class PostActionMenu
end

class PostCreateCompoundMenu < PostActionMenu
  def initialize(rk)
    puts "\n\nNEXT?"
    choose do |menu|
      menu.prompt = "What next?"
      menu.choice :show_updated_list_of_elements do
        rk.list_materials
        PostCreateCompoundMenu.new(rk)
      end
      menu.choice :add_another do CompoundCreator.new(rk) end
      menu.choice :main_menu do MainMenu.new(rk) end
      menu.choice :quit do ExitRoutine.new(rk) end
    end
  end
end

class PostCreateComparisonMenu < PostActionMenu
  def initialize(rk)
    puts "\n\nNEXT?"
    choose do |menu|
      menu.prompt = "What next?"
      menu.choice :show_updated_list_of_comparisons do 
        rk.list_comparisons
        PostCreateComparisonMenu.new(rk)
      end
      menu.choice :create_another_comparison do ComparisonCreator.new(rk) end
      menu.choice :main_menu do MainMenu.new(rk) end
      menu.choice :quit do ExitRoutine.new(rk) end
    end
  end
end

class PostShowAllElementsMenu < PostActionMenu
  def initialize(rk)
    puts "\n\nNEXT?"
    choose do |menu|
      menu.prompt = "What next?"
      menu.choice :main_menu do MainMenu.new(rk) end
      menu.choice :quit do ExitRoutine.new(rk) end
    end
  end
end

class ExitRoutine
  def initialize(rk)
    saveit = ask("Save settings? y/n")
    if saveit == "y"
      if $settings_file != nil
      choose do |menu|
        menu.prompt = "?"
        menu.choice :replace_existing do  end
        menu.choice :save_as_new do
          $settings_file = ask("Enter path and filename for new settings file")
        end
      end
    else
      $settings_file = ask("Enter path and filename for new settings file")
    end
    File.open($settings_file, 'w') do |settings|
      YAML.dump(rk, settings)
    end
    else
    exit
    end
  end
end