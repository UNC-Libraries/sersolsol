require 'csv'
require 'strscan'

require 'marc'
require 'marc_sersol'

# /bin script menus
require 'highline/import'


module SerSolSol
  require_relative 'sersolsol/version'

  require_relative 'sersolsol/package'
  require_relative 'sersolsol/package_data'
  require_relative 'sersolsol/record_editor'
end
