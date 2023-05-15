module SerSolSol
  class RecordEditor

    def initialize(loaded_packages, h773, h506, warnings)
      @all_loaded_packages = loaded_packages
      @h773 = h773
      @h506 = h506
      @warnings = warnings
    end

    # Performs edits on the MARC::Record passed in
    # Returns the edited MARC::Record
    def edit_marc_rec(rec)
      # This comes first because it is the most important part
      # Add 773s and 506s
      pkg_names = rec.packages

      # if a record's packages have distinct 506f's, set a flag to write
      # the package name to subfield 3 for each 506. We don't want to write
      # extra 506s for packages we're dropping (due to quality/dupe/whatever), so
      # only include packages being loaded.
      package_506_ct = pkg_names.select { |n| @all_loaded_packages.include?(n) }.
                                map { |n| @h506[n] }.
                                uniq.
                                length
      include_sf3 =
        if package_506_ct == 1
          false
        else
          true
        end

      pkg_names.each do |name|
        the_773 = @h773[name]
        the_506f = @h506[name]
        if @all_loaded_packages.include? name
          # the 773 part
          if the_773 != nil
            rec.append(MARC::DataField.new( '773', '0', ' ', ['t', the_773]))
          else
            @warnings << "The package #{name} has no associated 773 value."
          end

          if the_506f != nil
            unless the_506f == "na varies per title"
              if the_506f.downcase == "open access"
                marc_506 = MARC::DataField.new( '506', '0', ' ', ['f', 'Unlimited simultaneous users'])
              else
                marc_506 = MARC::DataField.new( '506', '1', ' ', ['a', 'Access limited to UNC Chapel Hill-authenticated users.'], ['f', the_506f])
              end
              marc_506.append(MARC::Subfield.new('3', name)) if include_sf3
              rec.append(marc_506)
            end
          else
            @warnings << "The package #{name} has no associated 506f value."
          end
        end
      end

      # The rest of the edits are organized by MARC field
      # 020 -- Delete 020 |c or |9 and provide |q
      m020 = rec.fields("020")
      if m020.count > 0
        m020.each do |f|
          sfs = f.codes
          exclude_sfs = ['c', '9']
          has_bad = sfs & exclude_sfs
          if has_bad.count > 0
            newfield = MARC::DataField.new(f.tag, f.indicator1, f.indicator2)
            f.each do |sf|
              if sf.code =~ /[^c9]/
                newfield.append(MARC::Subfield.new(sf.code, sf.value))
              end
            end
            rec.append(newfield) unless has_bad.count == sfs.count
            rec.fields.delete(f)
          end
        end
      end

      # Delete |9 from 044
      m044 = rec.fields("044")
      if m044.count > 0
        m044.each do |f|
          sfs = f.codes
          if sfs.include? "9"
            newfield = MARC::DataField.new(f.tag, f.indicator1, f.indicator2)
            f.each do |sf|
              if sf.code != "9"
                newfield.append(MARC::Subfield.new(sf.code, sf.value))
              end
            end
            rec.append(newfield) if sfs.count > 1
            rec.fields.delete(f)
          end
        end
      end

      # Change 060 |i to |b
      m060 = rec.fields("060")
      if m060.count > 0
        m060.each do |f|
          sfs = f.codes
          if sfs.include? "i"
            newfield = MARC::DataField.new(f.tag, f.indicator1, f.indicator2)
            f.each do |sf|
              if sf.code != "9"
                newfield.append(MARC::Subfield.new(sf.code, sf.value))
              else
                newfield.append(MARC::Subfield.new('b', sf.value))
              end
            end
            rec.append(newfield)
            rec.fields.delete(f)
          end
        end
      end

      # Move 088 |9 content to beginning of |a
      m088 = rec.fields("088")
      if m088.count > 0
        m088.each do |f|
          sfs = f.codes
          if sfs.include? "9"
            newfield = MARC::DataField.new(f.tag, f.indicator1, f.indicator2)
            sfa = ""
            sf9 = ""
            other_sfs = []
            f.each do |sf|
              if sf.code == "a"
                sfa = sf.value
              elsif sf.code == '9'
                sf9 = sf.value
              else
                other_sfs << sf
              end
            end
            new_sfa = "#{sf9} #{sfa}"
            newfield.append(MARC::Subfield.new('a', new_sfa))
            if other_sfs.count > 0
              other_sfs.each do |sf|
                newfield.append(MARC::Subfield.new(sf.code, sf.value))
              end
            end
            rec.append(newfield)
            rec.fields.delete(f)
          end
        end
      end

      # Delete $y from 1XX, 240
      the1xx = rec.find_all {|field| field.tag =~ /^(1..|240)/}
      if the1xx.count > 0
        the1xx.each do |f|
          sfs = f.codes
          if sfs.include? "y"
            newfield = MARC::DataField.new(f.tag, f.indicator1, f.indicator2)
            f.each do |sf|
              if sf.code != "y"
                newfield.append(MARC::Subfield.new(sf.code, sf.value))
              end
            end
            rec.append(newfield)
            rec.fields.delete(f)
          end
        end
      end

      # Split repeated 590|a into multiple fields
      m590 = rec.fields("590")
      if m590.count > 0
        m590.each do |f|
          sfs = []
          f.subfields.each do |s|
            sfs << s.code
          end
          if sfs.include? "a"
            if sfs.count("a") > 1
              f.each do |sf|
                if sf.code == "a"
                  newfield = MARC::DataField.new(f.tag, f.indicator1, f.indicator2)
                  newfield.append(MARC::Subfield.new(sf.code, sf.value))
                  rec.append(newfield)
                end
              end
              rec.fields.delete(f)
            end
          end
        end
      end

      # Set indicators/syntax for our custom 590s
      rec.each_by_tag("590") do |m590|
        next unless m590.indicator1 == ' '
        if m590["a"] =~ /^Provider: /
          m590.indicator1 = '0'
          m590["a"].gsub!(/^Provider: /, 'Content provider: ')
          m590["a"] << '.' unless m590["a"][-1] == '.'
        elsif m590["a"] =~ /^Vendor.supplied/
          m590.indicator1 = '1'
          m590["a"].gsub!(/^Vendor.supplied/, 'Vendor-supplied')
        end
      end





      # 710s - delete some 710s:
      rec.each_by_tag("710") do |m710|
        deleteme = "no"
        sfa = m710.find_all {|sf| sf.code == 'a'}
        sfa.each do |sf|
          deleteme = "yes" if /^SpringerLink \(Online service\).? */ =~ sf.value
          deleteme = "yes" if /^Springer Science+Business Media.? */ =~ sf.value
        end
        rec.fields.delete(m710) if deleteme == "yes"
      end

      # 773s - delete some 773s:
      rec.each_by_tag("773") do |m773|
        deleteme = "no"
        sft = m773.find_all {|sf| sf.code == 't'}
        sft.each do |sf|
          deleteme = "yes" if /^ACLS Humanities E-Book.? *$/ =~ sf.value
          deleteme = "yes" if /^Engineering Societies Library Collection \(Library of Congress\) *$/ =~ sf.value
          deleteme = "yes" if /^Springer eBooks *$/ =~ sf.value
        end
        rec.fields.delete(m773) if deleteme == "yes"
      end

      return rec
    end
  end
end

