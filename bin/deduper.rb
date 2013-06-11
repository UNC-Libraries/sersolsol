require 'rubygems'
require 'highline/import'
require 'yaml'
require "./lib/deduper"

$data = GetFile.new('data/ssdel.csv')
# $data = GetFile.new(ask("Enter path to file."))

$settings_file = nil
@rk = ""

setup = ask("Load a settings file? y/n")
$settings_file = ask("Enter path to settings file.") if setup == "y"

if $settings_file != nil
  @rk = File.open($settings_file) do |settings|
    YAML.load(settings)
  end
else
  @rk = RecordKeeper.new($data.headers)
end

MainMenu.new(@rk)
