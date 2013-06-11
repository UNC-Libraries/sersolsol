class CompoundCreator
  def initialize(record_keeper)
    section = "create compound comparable element"
    desc = "This function allows you to create more complex fields to compare.\nSay you have a title field and a subtitle field. Maybe you want to compare 'title + subtitle' and 'title' because sometimes the subtitle is squished into the title field.\nTo make this comparison, you first need to create the 'title + subtitle'element.\nTo create this compound field, assuming 'title' is 1 and 'subtitle' is 2, just enter 1,2 below and hit return.\nIf you wanted to include 'subtitle + title', you'd enter 2,1.\nYou can only combine 2 elements at a time."
    ConsoleHeading.new(section, desc)

    rk = record_keeper

    rk.list_materials

    fields = ask("Enter the numbers of the two fields you want to combine, in order, separated by commas.").split(/ ?, ?/)
    # TODO check that each field exists before combining.
    # TODO eventually let support combination of more than 2 at a time.
    c1 = rk.lookup_material_by_display_number(fields[0])
    c2 = rk.lookup_material_by_display_number(fields[1])
    rk.materials << Compound.new(c1, c2, rk)

    PostCreateCompoundMenu.new(rk)
  end
 end
