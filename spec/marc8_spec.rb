require 'spec_helper'
require 'marc/marc8/to_unicode'

RSpec.describe MARC::Marc8::ToUnicode do
  it 'normalizes MARC-8 text to Unicode' do
    marc8 = "$c\xC32008"

    expect(described_class.new.transcode(marc8)).to eq('$c©2008')
  end
end
