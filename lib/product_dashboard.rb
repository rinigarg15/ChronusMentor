# Steps to do in worst case scenario (and when there is an urgent need for the data)
# First: We need to run the product_dashboard:update_account_names rake task for all envs
# listed in the CUSTOMER_ENVS constant in the same order, using the following command
#   1. cap production deploy:invoke task='product_dashboard:update_account_names'
#   2. cap veteransadmin deploy:invoke task='product_dashboard:update_account_names'
#   ... till last env
# Second: We need to run the product_dashboard:update rake task for all envs
# listed in the CUSTOMER_ENVS constant in the same order, using the following command
#   1. cap production deploy:invoke task='product_dashboard:update'
#   2. cap veteransadmin deploy:invoke task='product_dashboard:update'
#   ... till last env

class ProductDashboard
  LOCKED = "locked"
  MUTEX_SHEET_NAME = "mutex"
  MAX_RETRY_COUNT = 20
  # Here an env is considered production only if the orgs in it is a customer. Not including demo here, in this list.
  CUSTOMER_ENVS = ["production", "veteransadmin", "generalelectric", "nch", "productioneu"]
  STAGING_ENVS = ["staging", "releasestaging1"]
  PROGRAM_WORKSHEET_NAME = "Track Data"
  ORGANIZATION_WORKSHEET_NAME = "Org Data"
  BRAINLIST_WORKSHEET_NAME = "DB Account Name List" # after cleanup replace with "Brain Master List Clone"
  ACCOUNT_NAME_COLUMN_NAME = "Account Name"
  STAGING_SPREADSHEET_ID = "1PZye9OHonfyB2ofz-LkzCEj3C74wZEbcRzQku5F6JQQ"
  PRODUCTION_SPREADSHEET_ID = "1UdlG-qzShsRYwJaY7OpnMiyPYNaZv4VIH8c78vqkquU"

  PROGRAM_DATA_TO_UPDATE = {
    account_name: {column_name: "Account Name"},
    url: {column_name: "Url"},
    status_string: {column_name: "Status", send_current: true},
    organization_name: {column_name: "Organization name"},
    name: {column_name: "Track Name"},
    mentor_enrollment_mode_string: {column_name: "Enrollment Mode - Mentor"},
    mentee_enrollment_mode_string: {column_name: "Enrollment Mode - Mentee"},
    matching_mode_string: {column_name: "Matching Mode"},
    engagement_mode_string: {column_name: "Engagement Mode"},
    current_users_with_unpublished_or_published_profiles_count: {column_name: "Current Users with unpublished or published profiles"},
    current_users_with_published_profiles_count: {column_name: "Current Users with published profiles"},
    current_connected_users_count: {column_name: "Current connected users"},
    current_active_connections_count: {column_name: "Current Number of connections"},
    created_at: {column_name: "Created On", time_data: true},
    last_login: {column_name: "Last Login", time_data: true},
    updated_at: {column_name: "Last Updated on", time_data: true, object_independent: true},
    users_with_unpublished_or_published_profiles_ytd_count: {column_name: "Users with unpublished or published profiles YTD"},
    users_with_published_profiles_ytd_count: {column_name: "Users with published profiles YTD"},
    users_connected_ytd_count: {column_name: "Users connected YTD"},
    connections_ytd_count: {column_name: "Connections YTD"},
    users_closed_connections_ytd_count: {column_name: "Users closed connections YTD"},
    closed_connections_ytd_count: {column_name: "Closed connections YTD"},
    users_completed_connections_ytd_count: {column_name: "Users completed connections YTD"},
    completed_connections_ytd_count: {column_name: "Completed connections YTD"},
    users_successful_completed_connections_ytd_count: {column_name: "Users successful completed connections YTD"},
    successful_completed_connections_ytd_count: {column_name: "Successful completed connections YTD"},
    get_flash_meeting_requested_ytd_count: {column_name: "Flash meetings requested YTD"},
    get_flash_meeting_accepted_ytd_count: {column_name: "Flash meetings accepted YTD"},
    get_flash_meeting_completed_ytd_count: {column_name: "Flash meetings completed YTD"},
    users_with_accepted_flash_meeting_ytd_count: {column_name: "Users with accepted flash meetings YTD"},
    users_with_completed_flash_meeting_ytd_count: {column_name: "Users with completed flash meetings YTD"}
  }

  ORGANIZATION_DATA_TO_UPDATE = {
    account_name: {column_name: "Account Name"},
    name: {column_name: "Organization name"},
    url: {column_name: "Url"},
    status_string: {column_name: "Status", send_current: true},
    tracks_count: {column_name: "Tracks"},
    current_users_with_unpublished_or_published_profiles_count: {column_name: "Current Users with unpublished or published profiles"},
    current_users_with_published_profiles_count: {column_name: "Current with published profiles"},
    current_connected_users_count: {column_name: "Current connected users"},
    current_active_connections_count: {column_name: "Current Number of connections"},
    created_at: {column_name: "Created On", time_data: true},
    last_login: {column_name: "Last Login", time_data: true},
    updated_at: {column_name: "Last Updated on", time_data: true, object_independent: true},
    users_with_unpublished_or_published_profiles_ytd_count: {column_name: "Users with unpublished or published profiles YTD"},
    users_with_published_profiles_ytd_count: {column_name: "Users with published profiles YTD"},
    users_connected_ytd_count: {column_name: "Users connected YTD"},
    connections_ytd_count: {column_name: "Connections YTD"},
    users_closed_connections_ytd_count: {column_name: "Users closed connections YTD"},
    closed_connections_ytd_count: {column_name: "Closed connections YTD"},
    users_completed_connections_ytd_count: {column_name: "Users completed connections YTD"},
    completed_connections_ytd_count: {column_name: "Completed connections YTD"},
    users_successful_completed_connections_ytd_count: {column_name: "Users successful completed connections YTD"},
    successful_completed_connections_ytd_count: {column_name: "Successful completed connections YTD"},
    get_flash_meeting_requested_ytd_count: {column_name: "Flash meetings requested YTD"},
    get_flash_meeting_accepted_ytd_count: {column_name: "Flash meetings accepted YTD"},
    get_flash_meeting_completed_ytd_count: {column_name: "Flash meetings completed YTD"},
    users_with_accepted_flash_meeting_ytd_count: {column_name: "Users with accepted flash meetings YTD"},
    users_with_completed_flash_meeting_ytd_count: {column_name: "Users with completed flash meetings YTD"}
  }

  attr_accessor :session, :spreadsheet, :debug, :brainlist_account_names_data, :objects_hsh, :allowed_for_env
  
  def initialize(options = {})
    unless Rails.env.test?
      @allowed_for_env = ENV["PRODUCT_DASHBOARD_KEY"].present?
      return unless @allowed_for_env
      set_session
      @spreadsheet = @session.spreadsheet_by_key(get_spreadsheet_id)
      @debug = true
    end
  end

  def update(options = {})
    raise_error "Session not available" unless @session
    raise_error "Spreadsheet not available" unless @spreadsheet
    avoid_collision
    begin
      lock_sheet
      if options[:account_names]
        update_account_names_only
      else
        get_brainlist_account_names_data
        update_objects_hsh
        update_program_data
        update_organization_data
      end
    rescue => error
      raise_error error.message
    ensure
      unlock_sheet
    end
  end

  class Error < StandardError
    attr_accessor :message
    def initialize(message); @message = message; end
    alias :to_s :message
  end

  def set_session
    tmp_file_name = "product-dashboard-service-account.json"
    tmp_file_name = (rand(36**10).to_s(36) + ".json") while File.exists?(tmp_file_name)
    File.write(tmp_file_name, ENV["PRODUCT_DASHBOARD_KEY"])
    @session = GoogleDrive::Session.from_service_account_key(tmp_file_name)
    File.delete(tmp_file_name)
  end

  def first_server?
    if CUSTOMER_ENVS.include?(Rails.env)
      CUSTOMER_ENVS.index(Rails.env).to_i == 0
    else
      STAGING_ENVS.index(Rails.env).to_i == 0
    end
  end

  def get_spreadsheet_id
    CUSTOMER_ENVS.include?(Rails.env) ? PRODUCTION_SPREADSHEET_ID : STAGING_SPREADSHEET_ID
  end

  def debug_print(str)
    puts(str) if @debug
  end

  def avoid_collision
    sleep(CUSTOMER_ENVS.index(Rails.env).to_i * 293)
  end

  def raise_error(message)
    raise Error.new(message)
  end

  def account_name_to_key(account_name)
    account_name
  end

  def update_objects_hsh
    @objects_hsh = {organizations: [], programs: []}
    programs_row_counter = 1
    list_of_account_names = @brainlist_account_names_data.map{|key, val| val[:account_name]}
    Organization.where(account_name: list_of_account_names).includes(:programs).index_by(&:account_name).each do |account_name, organization|
      @objects_hsh[:organizations] << {object: organization, row: @brainlist_account_names_data[account_name_to_key(account_name)][:row]}
      organization.programs.each do |program|
        @objects_hsh[:programs] << {object: program, row: programs_row_counter}
        programs_row_counter += 1
      end
    end
  end

  def lock_sheet
    retry_count = 0
    mutex = @spreadsheet.worksheets.find { |ws| ws.title == MUTEX_SHEET_NAME }
    while mutex[1, 1].present? && retry_count < MAX_RETRY_COUNT do
      retry_count += 1
      sleep(307)
      mutex.reload
    end
    raise_error "Not able to lock worksheet \"#{mutex.title}\" after maximum retries" if retry_count == MAX_RETRY_COUNT
    mutex[1, 1] = LOCKED
    mutex.save
  end

  def unlock_sheet
    mutex = @spreadsheet.worksheets.find { |ws| ws.title == MUTEX_SHEET_NAME }
    if mutex[1, 1].present?
      mutex[1, 1] = ""
      mutex.save
    end
  end

  def get_brainlist_account_names_data
    brainlist_worksheet = @spreadsheet.worksheets.find { |ws| ws.title == BRAINLIST_WORKSHEET_NAME }
    raise_error "Worksheet \"#{BRAINLIST_WORKSHEET_NAME}\" : Not Found" unless brainlist_worksheet
    account_name_column_number = brainlist_worksheet.rows[0].index(ACCOUNT_NAME_COLUMN_NAME)
    raise_error "Worksheet \"#{BRAINLIST_WORKSHEET_NAME}\" does not have column \"#{ACCOUNT_NAME_COLUMN_NAME}\"" unless account_name_column_number
    account_name_column_number += 1 # spreadsheet is 1 based index
    @brainlist_account_names_data = {}
    rows_count = brainlist_worksheet.rows.count
    2.upto(rows_count).each do |row|
      tmp_account_name = brainlist_worksheet[row, account_name_column_number]
      @brainlist_account_names_data[account_name_to_key(tmp_account_name)] = {row: row, account_name: tmp_account_name}
    end
  end

  def measure_time
    start_time = Time.now
    yield
    Time.now - start_time
  end

  def fill_all_account_names(worksheet, data_hsh)
    @brainlist_account_names_data.each do |account_name_key, hsh|
      worksheet[hsh[:row], data_hsh[:account_name][:column_number]] = hsh[:account_name]
    end
  end

  def clean_sheet(worksheet, data_hsh)
    rows_count = worksheet.rows.count
    2.upto(rows_count).each do |row|
      data_hsh.each do |key, hsh|
        worksheet[row, hsh[:column_number]] = ""
      end
    end
  end

  def updated_at
    Time.now
  end

  def update_data(worksheet, data_hsh, objects)
    headers = worksheet.rows[0]
    data_hsh.each do |key, hsh|
      index = headers.index(hsh[:column_name])
      raise_error "Column \"#{hsh[:column_name]}\" in Worksheet \"#{worksheet.title}\" : Not Found" unless index
      hsh[:column_number] = index + 1
    end
    organization_sheet_update = (worksheet.title == ORGANIZATION_WORKSHEET_NAME)
    if first_server?
      clean_sheet(worksheet, data_hsh)
      fill_all_account_names(worksheet, data_hsh) if organization_sheet_update
    end
    row_offset = if organization_sheet_update
      0
    elsif first_server?
      1
    else
      count = 0
      rows_count = worksheet.rows.count
      1.upto(rows_count).each do |row|
        count += 1 if worksheet[row, data_hsh[:account_name][:column_number]].present?
      end
      count
    end
    # We will query data object by object here, instead of eager loading because of the heavy load it puts on CPU adn DB
    # if we eager load entire org, programs, members, users etc, it is like eager loading almost entire db, rather we will
    # use complex scope, indexes (ES or Sphinx) available etc
    objects.each do |objects_hsh|
      object = objects_hsh[:object]
      row = objects_hsh[:row] + row_offset
      debug_print "Gathering and processing data for #{object.class.name} : \"#{object.name}\""
      total_time_taken = measure_time do
        data_hsh.each do |key, hsh|
          value = nil
          data_point_time = measure_time do
            send_params = [key]
            send_params << worksheet[row, hsh[:column_number]] if hsh[:send_current]
            value = (hsh[:object_independent] ? send(*send_params) : object.send(*send_params))
          end
          debug_print "  #{key} : #{data_point_time}" if data_point_time > 0.1
          value = DateTime.localize(value, format: :abbr_short) if hsh[:time_data]
          worksheet[row, hsh[:column_number]] = value
        end
      end
      debug_print "  total time: #{total_time_taken}" if total_time_taken > 0.5
    end
    worksheet.synchronize
  end

  def update_account_names_only
    worksheet = @spreadsheet.worksheets.find { |ws| ws.title == BRAINLIST_WORKSHEET_NAME }
    raise_error "Worksheet \"#{BRAINLIST_WORKSHEET_NAME}\" : Not Found" unless worksheet
    headers = worksheet.rows[0]
    index = headers.index("Account Name")
    raise_error "Column \"Account Name\" in Worksheet \"#{worksheet.title}\" : Not Found" unless index
    column_number = index + 1
    if first_server?
      rows_count = worksheet.rows.count
      2.upto(rows_count).each do |row|
        worksheet[row, column_number] = ""
      end
    end
    worksheet.synchronize
    rows_count = worksheet.rows.size
    existing_account_names = {}
    2.upto(rows_count).each do |row|
      existing_account_names[account_name_to_key(worksheet[row, column_number])] = true
    end
    current_row = rows_count
    Organization.all.reject(&:sandbox?).each do |organization|
      unless existing_account_names[account_name_to_key(organization.account_name)]
        current_row += 1
        worksheet[current_row, column_number] = organization.account_name
      end
    end
    worksheet.synchronize
  end

  def update_program_data
    program_worksheet = @spreadsheet.worksheets.find { |ws| ws.title == PROGRAM_WORKSHEET_NAME }
    raise_error "Worksheet \"#{PROGRAM_WORKSHEET_NAME}\" : Not Found" unless program_worksheet
    update_data(program_worksheet, PROGRAM_DATA_TO_UPDATE, @objects_hsh[:programs])
  end

  def update_organization_data
    organization_worksheet = @spreadsheet.worksheets.find { |ws| ws.title == ORGANIZATION_WORKSHEET_NAME }
    raise_error "Worksheet \"#{ORGANIZATION_WORKSHEET_NAME}\" : Not Found" unless organization_worksheet
    update_data(organization_worksheet, ORGANIZATION_DATA_TO_UPDATE, @objects_hsh[:organizations])
  end
end