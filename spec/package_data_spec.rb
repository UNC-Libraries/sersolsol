require 'spec_helper'

describe SerSolSol::PackageData do
  let(:spec_pkg_csv) { 'spec/data/fake_pkg_list.csv'}
  let(:subject) { described_class.new(spec_pkg_csv) }

  describe '.each' do
    it 'yields packages as raw data' do
      expect { |p| subject.each(&p) }.to yield_control
    end

    it 'returns packages as raw data' do
      expect(subject.each.first['name']).to be_truthy
    end

    it 'skips packages without names' do
      data_csv = 'spec/data/pkg_list_nameless_entry.csv'
      nameless_data = described_class.new(data_csv)
      expect(nameless_data.each.count).to eq(1)
    end
  end

  describe '.get' do
    it 'returns a Package' do
      sersol_name = 'Former Title'
      expect(subject.get(sersol_name)).to be_a(SerSolSol::Package)
    end

    it 'returns package for given sersol collection name' do
      sersol_name = 'Former Title'
      expect(subject.get(sersol_name).names).to include(sersol_name)
    end
  end

  describe '.loaded_packages' do
    it 'returns packages that are loaded' do
      loaded_package = 'Fake AAL collection, loaded'
      expect(subject.loaded_packages.any? { |p| p.names.include?(loaded_package)}).to be true
    end

    it 'excludes dropped packages' do
      dropped_package = 'Fake AAL collection, dropped'
      expect(subject.loaded_packages.any? { |p| p.names.include?(dropped_package)}).to be false
    end

    it 'can be filtered to a specific library', :aggregate_failures do
      aal_package = 'Fake AAL collection, loaded'
      law_package = 'Fake Law collection, loaded'
      loaded_law_packages = subject.loaded_packages(:law)
      expect(loaded_law_packages.any? { |p| p.names.include?(aal_package)}).to be false
      expect(loaded_law_packages.any? { |p| p.names.include?(law_package)}).to be true
    end
  end
end
