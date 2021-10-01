require_relative './../../test_helper.rb'

class ProductDashboardTest < ActiveSupport::TestCase
  class WorksheetMock
    attr_accessor :title, :data
    def []=(*args)
      row, col, val = args
      row -= 1
      col -= 1
      @data[row] ||= []
      @data[row][col] = val
    end
    def [](*args)
      row, col = args
      row -= 1
      col -= 1
      @data[row].try(:[], col)
    end
    def rows; @data; end
    def synchronize
      @data = @data.select{ |row| row && row.map(&:present?).uniq.include?(true) }
    end
  end

  class SpreadsheetMock
    attr_accessor :worksheets
  end

  def setup
    super
    programs(:org_no_subdomain).update_attribute(:account_name, "sandbox tmp")
    @product_dashboard = ProductDashboard.new
    @product_dashboard.session = true
    @product_dashboard.spreadsheet = SpreadsheetMock.new
  end

  def test_update_objects_hsh
    @product_dashboard.brainlist_account_names_data = {
      "account1" => {row: 2, account_name: "account1"},
      "org_primary_account" => {row: 3, account_name: "org_primary_account"},
      "account2" => {row: 4, account_name: "account2"},
      "org_foster_account" => {row: 5, account_name: "org_foster_account"}
    }
    @product_dashboard.update_objects_hsh
    @product_dashboard.objects_hsh
    assert_equal [{object: programs(:org_primary), row: 3}, {object: programs(:org_foster), row: 5}], @product_dashboard.objects_hsh[:organizations]
    program_objects = []
    counter = 1
    Organization.where(account_name: ["org_primary_account", "org_foster_account"]).includes(:programs).index_by(&:account_name).each do |account_name, org|
      org.programs.each do |program|
        program_objects << {object: program, row: counter}
        counter += 1
      end
    end
    assert_equal program_objects, @product_dashboard.objects_hsh[:programs]
  end

  def test_get_brainlist_account_names_data
    worksheet = WorksheetMock.new
    worksheet.title = ProductDashboard::BRAINLIST_WORKSHEET_NAME
    worksheet.data = [["Account Name", "col2", "col3"], ["account1", "v2", "v3"], ["account2", "v32", "v33"]]
    @product_dashboard.spreadsheet.worksheets = [worksheet]
    @product_dashboard.get_brainlist_account_names_data
    assert_equal_hash({"account1"=>{:row=>2, :account_name=>"account1"}, "account2"=>{:row=>3, :account_name=>"account2"}}, @product_dashboard.brainlist_account_names_data)
  end

  def test_fill_all_account_names
    worksheet = WorksheetMock.new
    worksheet.title = ProductDashboard::ORGANIZATION_WORKSHEET_NAME
    worksheet.data = [["Account Name", "h2", "h3"], ["", "v12", ""], ["", "v22", ""]]
    data_hsh = {account_name: {column_number: 1}}
    @product_dashboard.brainlist_account_names_data = {"account1"=>{:row=>2, :account_name=>"account1"}, "account2"=>{:row=>3, :account_name=>"account2"}, "account3"=>{:row=>4, :account_name=>"account3"}}
    @product_dashboard.fill_all_account_names(worksheet, data_hsh)
    assert_equal [["Account Name", "h2", "h3"], ["account1", "v12", ""], ["account2", "v22", ""], ["account3"]], worksheet.data
  end

  def test_clean_sheet
    worksheet = WorksheetMock.new
    worksheet.data = [["h1", "h2", "h3"], ["v11", "v12", "v13"], ["v21", "v22", "v23"]]
    data_hsh = {
      h1: {column_name: "h1", column_number: 1},
      h3: {column_name: "h3", column_number: 3}
    }
    @product_dashboard.clean_sheet(worksheet, data_hsh)
    assert_equal [["h1", "h2", "h3"], ["", "v12", ""], ["", "v22", ""]], worksheet.data
  end

  def test_update_data_for_org_first_server
    worksheet = WorksheetMock.new
    worksheet.title = ProductDashboard::ORGANIZATION_WORKSHEET_NAME
    worksheet.data = [["Account Name", "Other", "Id"], ["account1del", "v21", "id1"]]
    data_hsh = {
      account_name: {column_name: "Account Name"},
      id: {column_name: "Id"}
    }
    objects = [{object: programs(:org_primary), row: 3}, {object: programs(:org_foster), row: 5}]
    @product_dashboard.brainlist_account_names_data = {
      "account1"=>{:row=>2, :account_name=>"account1"},
      "org_primary_account"=>{:row=>3, :account_name=>"org_primary_account"},
      "account3"=>{:row=>4, :account_name=>"account3"},
      "org_foster_account"=>{:row=>5, :account_name=>"org_foster_account"}
    }
    @product_dashboard.update_data(worksheet, data_hsh, objects)
    assert_equal [["Account Name", "Other", "Id"], ["account1", "v21", ""], ["org_primary_account", nil, programs(:org_primary).id], ["account3"], ["org_foster_account", nil, programs(:org_foster).id]], worksheet.data
  end

  def test_update_data_for_org_other_server
    worksheet = WorksheetMock.new
    worksheet.title = ProductDashboard::ORGANIZATION_WORKSHEET_NAME
    worksheet.data = [
      ["Account Name", "Other", "Id"],
      ["account1", "v21", ""],
      ["org_primary_account", "v31", ""],
      ["account3", "v41", ""],
      ["org_foster_account", "v51", ""]
    ]
    data_hsh = {
      account_name: {column_name: "Account Name"},
      id: {column_name: "Id"}
    }
    objects = [{object: programs(:org_primary), row: 3}, {object: programs(:org_foster), row: 5}]
    assert @product_dashboard.respond_to?(:first_server?)
    @product_dashboard.expects(:first_server?).returns(false)
    @product_dashboard.update_data(worksheet, data_hsh, objects)
    assert_equal [["Account Name", "Other", "Id"], ["account1", "v21", ""], ["org_primary_account", "v31", programs(:org_primary).id], ["account3", "v41", ""], ["org_foster_account", "v51", programs(:org_foster).id]], worksheet.data
  end

  def test_update_data_for_program_first_server
    worksheet = WorksheetMock.new
    worksheet.title = ProductDashboard::PROGRAM_WORKSHEET_NAME
    worksheet.data = [["Account Name", "Other", "Id"], ["account1del", "v21", "id1"]]
    data_hsh = {
      account_name: {column_name: "Account Name"},
      id: {column_name: "Id"}
    }
    objects = [{object: programs(:albers), row: 1}, {object: programs(:ceg), row: 2}]
    @product_dashboard.update_data(worksheet, data_hsh, objects)
    assert_equal [["Account Name", "Other", "Id"], ["org_primary_account", "v21", programs(:albers).id], ["org_anna_univ_account", nil, programs(:ceg).id]], worksheet.data
  end

  def test_update_data_for_program_other_server
    worksheet = WorksheetMock.new
    worksheet.title = ProductDashboard::PROGRAM_WORKSHEET_NAME
    worksheet.data = [["Account Name", "Other", "Id"], ["account1nodel", "v21", "id1"]]
    data_hsh = {
      account_name: {column_name: "Account Name"},
      id: {column_name: "Id"}
    }
    objects = [{object: programs(:albers), row: 1}, {object: programs(:ceg), row: 2}]
    assert @product_dashboard.respond_to?(:first_server?)
    @product_dashboard.expects(:first_server?).times(2).returns(false)
    @product_dashboard.update_data(worksheet, data_hsh, objects)
    assert_equal [["Account Name", "Other", "Id"], ["account1nodel", "v21", "id1"], ["org_primary_account", nil, programs(:albers).id], ["org_anna_univ_account", nil, programs(:ceg).id]], worksheet.data
  end

  def test_update_account_names_only_for_first_server
    worksheet = WorksheetMock.new
    worksheet.title = ProductDashboard::BRAINLIST_WORKSHEET_NAME
    worksheet.data = [["Account Name"], ["account1"], ["account2"]]
    @product_dashboard.spreadsheet.worksheets = [worksheet]
    @product_dashboard.update_account_names_only
    ans = [["Account Name"]]
    Organization.all.reject(&:sandbox?).each { |org| ans << [org.account_name] }
    assert_equal ans, worksheet.data
  end

  def test_update_account_names_only_for_other_servers
    worksheet = WorksheetMock.new
    worksheet.title = ProductDashboard::BRAINLIST_WORKSHEET_NAME
    worksheet.data = [["Account Name"], ["account1"], ["account2"]]
    assert @product_dashboard.respond_to?(:first_server?)
    @product_dashboard.expects(:first_server?).returns(false)
    @product_dashboard.spreadsheet.worksheets = [worksheet]
    @product_dashboard.update_account_names_only
    programs(:org_no_subdomain).update_attribute(:account_name, "sandbox tmp")
    ans = [["Account Name"], ["account1"], ["account2"]]
    Organization.all.reject(&:sandbox?).each { |org| ans << [org.account_name] }
    assert_equal ans, worksheet.data
  end

  def test_update_callbacks
    assert @product_dashboard.respond_to?(:avoid_collision)
    assert @product_dashboard.respond_to?(:lock_sheet)
    assert @product_dashboard.respond_to?(:get_brainlist_account_names_data)
    assert @product_dashboard.respond_to?(:update_objects_hsh)
    assert @product_dashboard.respond_to?(:update_program_data)
    assert @product_dashboard.respond_to?(:update_organization_data)
    assert @product_dashboard.respond_to?(:unlock_sheet)
    @product_dashboard.expects(:avoid_collision).once.returns(true)
    @product_dashboard.expects(:lock_sheet).once.returns(true)
    @product_dashboard.expects(:get_brainlist_account_names_data).once.returns(true)
    @product_dashboard.expects(:update_objects_hsh).once.returns(true)
    @product_dashboard.expects(:update_program_data).once.returns(true)
    @product_dashboard.expects(:update_organization_data).once.returns(true)
    @product_dashboard.expects(:unlock_sheet).once.returns(true)
    @product_dashboard.update
  end

  def test_update_account_names_callbacks
    assert @product_dashboard.respond_to?(:avoid_collision)
    assert @product_dashboard.respond_to?(:lock_sheet)
    assert @product_dashboard.respond_to?(:update_account_names_only)
    assert @product_dashboard.respond_to?(:unlock_sheet)
    @product_dashboard.expects(:avoid_collision).once.returns(true)
    @product_dashboard.expects(:lock_sheet).once.returns(true)
    @product_dashboard.expects(:update_account_names_only).once.returns(true)
    @product_dashboard.expects(:unlock_sheet).once.returns(true)
    @product_dashboard.update(account_names: true)
  end
end