module SerSolSol
  class Package
    attr_reader :library, :names, :title, :users

    def initialize(datarow)
      @names = datarow['name'].split(';;;')

      # loading library
      @library = if datarow['aalload']
                   :aal
                  elsif datarow['hslload']
                    :hsl
                  elsif datarow['lawload']
                    :law
                  end

      # title used for 773
      @title = datarow['773title']

      # User limit used for 506
      @users = datarow['506access']
    end

    def load?
      @library != nil
    end
  end
end
