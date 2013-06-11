# Elements correspond to the columns of the original spreadsheet.
# An Element instance keeps track of the name of the field and the index
#  where values for that field can be retrieved from data arrays read in
#  from the original spreadsheet.

class Element
# col = for column. the index of the data array
# name = the name in the header for this column
  attr_accessor :ind, :name

  def initialize(ind, name)
    @name = name
    @ind = ind
  end

  # returns number (string) to be displayed in menus
  def displaynum
   n = @ind + 1
   n.to_s
  end
end
