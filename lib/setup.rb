require 'date'
require 'facets'
require 'mongo'
require 'hitimes'

require './lib/manager'
$marc_root = 'data/ssmrc'
$package_data = 'data/pkg_list.csv'

  $db = Mongo::Connection.new.db('wtf')
  $pcoll = $db['packages']
  $scoll = $db['states']
  $ecoll = $db['errors']

$pcoll.create_index([['names', Mongo::ASCENDING]])
$scoll.create_index([['ssid', Mongo::ASCENDING], ['date', Mongo::DESCENDING]])