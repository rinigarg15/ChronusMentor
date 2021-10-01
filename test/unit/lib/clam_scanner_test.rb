require_relative './../../test_helper.rb'

class ClamScannerTest < ActiveSupport::TestCase
  def test_scan_file
  	if ENV['TDDIUM'] == false
  	 #ClamAV Demon does not run on Tddium hosts
  	 ClamScanner.expects(:clamd_running?).returns(true)
    end
    assert ClamScanner.scan_file(File.join(Rails.root, 'test/fixtures/files/big.pdf'))
    ClamScanner.expects(:clamd_running?).returns(false)
    assert ClamScanner.scan_file(File.join(Rails.root, 'test/fixtures/files/big.pdf'))
  end
end