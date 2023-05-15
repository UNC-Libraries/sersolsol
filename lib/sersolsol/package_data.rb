module SerSolSol
  class PackageData
    def initialize(datafile)
      @datafile = datafile
    end

    def each(&block)
      return to_enum(:each) unless block_given?

      each_raw(&block)
    end

    # Returns a list of Packages that get loaded. Can be filtered to a
    # library-specific list via optional filter
    #  all packages = loaded_packages
    #  AAL/UNL packages = loaded_packages(:aal)
    def loaded_packages(library = nil)
      return packages.select(&:load?) unless library

      loaded_packages.select { |p| p.library == library }
    end

    # Returns a list of names of packages that get loaded. Can be filtered to a
    # library-specific list via optional filter
    def loaded_package_names(library: nil)
      loaded_packages(library: library).flat_map(&:names)
    end

    # Returns a list of names of 773s/titles that get loaded.
    def loaded_773s
      loaded_packages.map(&:title)
    end

    def get(sersol_name)
      packages_by_name[sersol_name]
    end

    private

    # pkg_list.csv uses a BOM to help Excel detect the encoding and used
    # Windows newlines because it is normally edited on Windows. We clean
    # those things up here to help csv parse the file/data.
    def clean_data
      data = File.read(@datafile, :encoding => 'bom|utf-8')
      data.tr("\r", '')
    end

    # Yields each package as raw data (e.g. csv row)
    def each_raw
      pdata = CSV.parse(clean_data, :headers => true)
      pdata.each do |row|
        yield row if row['name']
      end
    end

    #returns list of packages as `Package`s
    def packages
      return @packages if @packages

      @packages = []
      each_raw do |row|
        @packages << Package.new(row)
      end

      @packages
    end

    def packages_by_name
      return @packages_by_name if @packages_by_name

      @packages_by_name = {}
      packages.each do |p|
        p.names.each do |name|
          # Multple packages shouldn't be assigned the same name in pkg_list.csv,
          # but it could be done by mistake. If it happens, we'll use the
          # last name:package association in the csv, and we're not providing
          # any kind of warning.
          @packages_by_name[name] = p
        end
      end

      @packages_by_name
    end
  end
end
