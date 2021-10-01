class CsvImportsController < ApplicationController
  # Preloading a class whose instances are cached
  [CsvImporter::ProcessedRow]
  
  skip_before_action :login_required_in_program, :require_program
  before_action :login_required_in_organization
  before_action :set_program_level_import, :set_import_level, :set_is_dormant_import_for_standalone_org
  allow :exec => :admin_at_current_level?
  before_action :set_user_csv_import_for_non_imported, :only => [:edit, :update, :destroy, :validation_information, :validation_data_popup, :import_data, :map_csv_columns, :create_mapping]
  before_action :set_user_csv_import, :only => [:completed, :records]

  MAX_NUMBER = 100000
  MAX_NUMBER_OF_USER_RECORDS = 1000

  module DataPopup
    DEFAULT_PAGE = 1
    PER_PAGE = 10

    module Type
      ACTIVE = "active"
      PENDING = "pending"
      INVITE = "invite"
      UPDATE = "update"
      SUSPENDED = "suspended"
      ERROR = "error"
      ADDED = "added"

      METHOD_MAPPING = {
        ACTIVE => :active_profile?,
        PENDING => :pending_profile?,
        INVITE => :is_user_to_be_invited?,
        UPDATE => :is_user_to_be_updated?,
        SUSPENDED => :is_suspended_member?,
        ERROR => :can_show_errors?,
        ADDED => :is_user_to_be_added?
      }
    end
  end

  def new
    @program_roles = @current_program.roles if @program_level_import
  end

  def create
    if (error = validate_file(params[:user_csv])).present?
      flash[:error] = error
      redirect_to new_csv_import_path(:organization_level => @standalone_dormant_import)
    elsif not_a_valid_role_based_choice?
      handle_role_error(new_csv_import_path(:organization_level => @standalone_dormant_import))
    else
      @user_csv_import, valid_encoding = UserCsvImport.save_csv_file(@current_import_level, @current_member, params[:user_csv])
      if @user_csv_import.errors.present?
        flash[:error] = "csv_import.content.upload_valid_csv".translate
        redirect_to new_csv_import_path(:organization_level => @standalone_dormant_import)
      elsif !valid_encoding
        flash[:error] = "csv_import.content.encoding_error".translate
        redirect_to new_csv_import_path(:organization_level => @standalone_dormant_import)
      else
        handle_create_or_update_success
      end
    end
  end

  def edit
    @selected_roles = @user_csv_import.selected_roles if @program_level_import && @user_csv_import.present?
    @program_roles = @current_program.roles if @program_level_import

    render :action => :new
  end

  def update
    if not_a_valid_role_based_choice?
      handle_role_error(edit_csv_import_path(@user_csv_import, :organization_level => @standalone_dormant_import))
    else
      handle_create_or_update_success
    end
  end

  def map_csv_columns
    @selected_roles = @user_csv_import.selected_roles if @program_level_import
    @csv_column_headers = @user_csv_import.csv_headers_for_dropdown
    @mandatory_column_keys = @user_csv_import.map_mandatory_column_keys(@program_level_import, @selected_roles)
    @profile_column_keys = @user_csv_import.map_non_mandatory_columns_keys(@selected_roles, is_super_console: super_console?)
    @example_column_values = @user_csv_import.example_column_values
    @saved_mapping = UserCsvImport.get_processed_saved_mapping(@user_csv_import.program.previous_user_csv_import_info_hash[:processed_csv_import_params], @user_csv_import.info_hash[:processed_csv_import_params], @csv_column_headers, @mandatory_column_keys)
    @showing_saved_mapping = @saved_mapping.present?
  end

  def create_mapping
    @selected_roles = @user_csv_import.selected_roles if @program_level_import
    @user_csv_import.save_mapping_params(params[:csv_dropdown].try(:to_unsafe_h), params[:profile_dropdown].try(:to_unsafe_h))
    @user_csv_import.save_processed_csv_import_params

    redirect_to validation_information_csv_import_path(@user_csv_import, :organization_level => @standalone_dormant_import)
  end

  def validation_information
    options = {program: current_program_at_import_level, cannot_add_organization_members: @program_level_import && !@current_program.allow_track_admins_to_access_all_users && !wob_member.admin?, profile_questions: @current_organization.profile_questions.includes(question_choices: :translations)}
    options.merge!({role_names: @user_csv_import.selected_roles}) if @program_level_import
    data_processor = CsvImporter::DataProcessor.new(@user_csv_import, @current_organization, options)
    @result = data_processor.process
  end

  def validation_data_popup
    set_validation_data_popup_variables
    @data = CsvImporter::ProcessedRow.select_rows_where(@all_data, DataPopup::Type::METHOD_MAPPING[@type]).paginate(page: @page, per_page: DataPopup::PER_PAGE)
    respond_to do |format|
      format.html {render :partial => "csv_imports/validation_data_popup"}
      format.js
    end
  end

  def import_data
    options = { current_user: current_user_at_import_level, questions: @user_csv_import.profile_questions.to_a, locale: current_locale, is_super_console: super_console? }
    options.merge!({role_names: @user_csv_import.selected_roles}) if @program_level_import
    importer = CsvImporter::ImportUsers.new(@user_csv_import, @current_organization, current_program_at_import_level, options)
    importer.delay(:queue => DjQueues::HIGH_PRIORITY).import
    @user_csv_import.update_attribute(:imported, true)
    @progress = importer.progress
  end

  def completed
    failed_records = fetch_failed_records
    if failed_records.present?
      flash[:warning] = "csv_import.content.import_failure_message_html".translate(download_url: records_csv_import_path(@user_csv_import, format: :csv, failed: true, organization_level: @standalone_dormant_import))
    else
      flash[:notice] = "csv_import.content.import_success".translate
    end
    redirect_to((@program_level_import || @standalone_dormant_import) ? manage_program_path : manage_organization_path)
  end

  def records
    respond_to do |format|
      format.csv do
        records = fetch_records
        csv_file_name = "#{File.basename(@user_csv_import.local_csv_file_path, '.csv')}_#{Time.now.to_i}.csv"
        data = CsvImporter::GenerateCsv.for_data(records, @user_csv_import, params["type"] == DataPopup::Type::ERROR)
        send_csv(data, :disposition => "attachment; filename=#{csv_file_name}")
      end
    end
  end

  def destroy
    UserCsvImport.clean_up_user_csv_file(@user_csv_import.local_csv_file_path)
    @user_csv_import.destroy

    redirect_to new_csv_import_path(:organization_level => @standalone_dormant_import)
  end

  private

  def set_program_level_import
    @program_level_import = @current_program.present? && !@standalone_org_level_access
  end

  def set_import_level
    @current_import_level = @program_level_import ? @current_program : @current_organization
  end

  def current_program_at_import_level
    @program_level_import ? @current_program : nil
  end

  def current_user_at_import_level
    @program_level_import ? current_user : nil
  end

  def set_is_dormant_import_for_standalone_org
    @standalone_dormant_import = !@program_level_import && @current_organization.standalone?
  end

  def set_validation_data_popup_variables
    @all_data = CsvImporter::Cache.read(@user_csv_import)
    @page = params["page"]||DataPopup::DEFAULT_PAGE
    @type = params["type"]||DataPopup::Type::ERROR
  end

  def handle_create_or_update_success
    @selected_roles = params[:role] if @program_level_import && params[:role_option] == UserCsvImport::RoleOption::SelectRoles
    @user_csv_import.update_or_save_role(@selected_roles)
    redirect_to map_csv_columns_csv_import_path(@user_csv_import, :organization_level => @standalone_dormant_import)
  end

  def handle_role_error(redirect_to_path)
    flash[:error] = "csv_import.content.select_a_role".translate
    redirect_to redirect_to_path
  end

  def validate_file(csv_stream)
    if !csv_stream || !File.size?(csv_stream.path)
      "csv_import.content.upload_valid_csv".translate
    elsif File.extname(csv_stream.original_filename) != ".csv"
      "csv_import.content.not_a_csv_file".translate(:instructions => "<a href='https://support.office.com/en-us/article/Import-or-export-text-txt-or-csv-files-5250ac4c-663c-47ce-937b-339e391393ba#bmexport' target='_blank'>#{'csv_import.content.instructions_text'.translate}</a>".html_safe)
    elsif (!super_console? && get_number_of_user_records(csv_stream.path) > MAX_NUMBER_OF_USER_RECORDS)
      "csv_import.content.row_limit_exceeded".translate(row_limit: MAX_NUMBER_OF_USER_RECORDS)
    end
  end

  def get_number_of_user_records(path)
    `wc -l < #{path.shellescape}`.to_i - 1
  end

  def not_a_valid_role_based_choice?
     @program_level_import && (!params[:role_option].present? || (params[:role_option] == UserCsvImport::RoleOption::SelectRoles && !params[:role].present?))
  end

  def set_user_csv_import_for_non_imported
    @user_csv_import = @current_import_level.user_csv_imports.not_imported.find(params[:id])
  end

  def set_user_csv_import
    @user_csv_import = @current_import_level.user_csv_imports.find(params[:id])
  end

  def fetch_failed_records
    CsvImporter::Cache.read_failures(@user_csv_import)
  end

  def fetch_records
    params["failed"].present? ? fetch_failed_records : fetch_records_for(params["type"])
  end

  def fetch_records_for(type)
    data = CsvImporter::Cache.read(@user_csv_import)
    CsvImporter::ProcessedRow.select_rows_where(data, DataPopup::Type::METHOD_MAPPING[type])
  end
end