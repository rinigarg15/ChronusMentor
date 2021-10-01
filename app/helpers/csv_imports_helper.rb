module CsvImportsHelper

  module Headers
    IMPORT_DATA = 1
    MAP_CONTENT = 2
    CREATE_USERS = 3
  end

  def csv_imports_total_added_information(id, result, program_term, org_name, standalone_dormant_import)
    help_text = content_tag(:span, "", :class => "fa fa-info-circle", :id => "unpublished_help_text")
    if result[:active_profiles].present? && !result[:active_profiles].zero? && result[:pending_profiles].present? && !result[:pending_profiles].zero?
      "csv_import.content.validation_information.new_users_active_and_pending_html".translate(count: result[:total_added], active_link: csv_imports_active_profile_link(id, result[:active_profiles], standalone_dormant_import), pending_link: csv_imports_pending_profile_link(id, result[:pending_profiles], standalone_dormant_import), tooltip: help_text, program: program_term)
    elsif result[:active_profiles].present? && !result[:active_profiles].zero?
      "csv_import.content.validation_information.new_users_active_html".translate(count: result[:active_profiles], active_link: csv_imports_active_profile_link(id, result[:active_profiles], standalone_dormant_import), program: program_term)
    elsif result[:pending_profiles].present? && !result[:pending_profiles].zero?
      "csv_import.content.validation_information.new_users_pending_html".translate(count: result[:pending_profiles], pending_link: csv_imports_pending_profile_link(id, result[:pending_profiles], standalone_dormant_import), program: program_term, tooltip: help_text)
    else
      "csv_import.content.validation_information.new_members_html".translate(count: result[:total_added], count_link: csv_imports_added_link(id, result[:total_added], standalone_dormant_import), org_name: org_name)
    end
  end

  def csv_imports_active_profile_link(id, count, standalone_dormant_import)
    csv_imports_validation_link(id, count, CsvImportsController::DataPopup::Type::ACTIVE, standalone_dormant_import)
  end

  def csv_imports_pending_profile_link(id, count, standalone_dormant_import)
    csv_imports_validation_link(id, count, CsvImportsController::DataPopup::Type::PENDING, standalone_dormant_import)
  end

  def csv_imports_users_to_invite_link(id, count, standalone_dormant_import)
    csv_imports_validation_link(id, count, CsvImportsController::DataPopup::Type::INVITE, standalone_dormant_import)
  end

  def csv_imports_users_to_update_link(id, count, standalone_dormant_import)
    csv_imports_validation_link(id, count, CsvImportsController::DataPopup::Type::UPDATE, standalone_dormant_import)
  end

  def csv_imports_suspended_members_link(id, count, standalone_dormant_import)
    csv_imports_validation_link(id, count, CsvImportsController::DataPopup::Type::SUSPENDED, standalone_dormant_import)
  end

  def csv_imports_error_link(id, count, standalone_dormant_import)
    csv_imports_validation_link(id, count, CsvImportsController::DataPopup::Type::ERROR, standalone_dormant_import, "csv_import.content.validation_information.errors_link_text".translate(count: count))
  end

  def csv_imports_added_link(id, count, standalone_dormant_import)
    csv_imports_validation_link(id, count, CsvImportsController::DataPopup::Type::ADDED, standalone_dormant_import)
  end

  def csv_imports_validation_link(id, count, type, standalone_dormant_import, link_to = nil)
    link_to = count unless link_to.present?
    count.zero? ? count : link_to(link_to, "javascript:void(0);", class: "remote-popup-link", id: "imports_validation_data_#{type}", data: {url: validation_data_popup_csv_import_path(id, type: type, :organization_level => standalone_dormant_import, format: :html), largemodal: true})
  end

  def csv_imports_cell_data(column, value, row_index, errors, col_index)
    error_present = errors.keys.include?(column)
    element_class = error_present ? "text-danger" : ""
    content = error_present ? csv_imports_error(column, row_index, errors, col_index) : "".html_safe
    content + content_tag(:td, content_tag(:div, value, class: "p-xs #{element_class}", id: "#{col_index}_#{row_index}"), :class => "no-padding") 
  end

  def csv_imports_error(column, row_index, errors, col_index)
    all_errors = errors[column]||errors[column.to_sym]
    tip_text = csv_imports_error_list(all_errors)
    tooltip("#{col_index}_#{row_index}", tip_text)
  end

  def csv_imports_error_list(errors)
    content = "".html_safe
    errors.each do |error|
      content += content_tag(:li, error)
    end
    content_tag(:div) do
      content_tag(:ul, :class => "p-l-sm") do
        content
      end
    end
  end

  def add_bulk_users_wizard
    wizard_info = ActiveSupport::OrderedHash.new
    wizard_info[Headers::IMPORT_DATA] = {:label => "csv_import.header.import_data".translate }
    wizard_info[Headers::MAP_CONTENT] = {:label => "csv_import.header.map_content_v1".translate }
    wizard_info[Headers::CREATE_USERS] = {:label => "csv_import.header.create_users".translate }
    wizard_info
  end

  def map_user_columns_wizard(user_csv_import, standalone_dormant_import)
    wizard_info = ActiveSupport::OrderedHash.new
    wizard_info[Headers::IMPORT_DATA] = {:label => "csv_import.header.import_data".translate, :url => edit_csv_import_path(user_csv_import, :organization_level => standalone_dormant_import) }
    wizard_info[Headers::MAP_CONTENT] = {:label => "csv_import.header.map_content_v1".translate }
    wizard_info[Headers::CREATE_USERS] = {:label => "csv_import.header.create_users".translate }
    wizard_info
  end

  def create_users_wizard(user_csv_import, standalone_dormant_import)
    wizard_info = ActiveSupport::OrderedHash.new
    wizard_info[Headers::IMPORT_DATA] = {:label => "csv_import.header.import_data".translate, :url => edit_csv_import_path(user_csv_import, :organization_level => standalone_dormant_import) }
    wizard_info[Headers::MAP_CONTENT] = {:label => "csv_import.header.map_content_v1".translate, :url => map_csv_columns_csv_import_path(user_csv_import, :organization_level => standalone_dormant_import) }
    wizard_info[Headers::CREATE_USERS] = {:label => "csv_import.header.create_users".translate }
    wizard_info
  end

  def render_dropdown_for_csv_headers(index, csv_col_headers, saved_mapping, column_key = nil)
    options = [["csv_import.import_user_csv_headers.select_imported_field_v1".translate, "select_a_column"]]
    if saved_mapping.present?
      mapped_key = column_key.present? ? saved_mapping.key(column_key) : saved_mapping.keys.first
      selected_choice = csv_col_headers.index(mapped_key).to_s
      saved_mapping.reject!{|k,v| k == mapped_key} if column_key
    end
    csv_col_headers.each_with_index do |col_header, header_index|
      options << [escape_javascript(col_header), header_index]
    end
    column_class = column_key.present? ? "cjs_mandatory_csv_column" : "cjs_optional_csv_column"
    select_tag("[csv_dropdown][#{index}]", options_for_select(options, selected_choice), :class => "form-control cjs_csv_header_dropdown cjs_user_csv_dropdown #{column_class}")
  end

  def render_dropdown_for_column_options(index, csv_col_headers, profile_column_keys, saved_mapping)
    options = []
    if saved_mapping.present?
      mapped_csv_key = saved_mapping.keys.first
      selected_choice = saved_mapping[mapped_csv_key] if profile_column_keys.index(saved_mapping[mapped_csv_key]).present?
      saved_mapping.reject!{|k,v| k == mapped_csv_key}
    end
    selected_choice = UserCsvImport::CsvMapColumns::DONT_MAP unless selected_choice.present?
    profile_column_keys.each do |key|
      options << [UserCsvImport.column_key_dropdown_heading(key), key]
    end
    select_tag("[profile_dropdown][#{index}]", options_for_select(options, selected_choice), :class => "cjs_profile_header_dropdown cjs_user_csv_dropdown form-control")
  end

  def get_original_error_columns(errors, field_to_csv_mapping)
    error_columns = {}
    errors.each do |k, v|
      original_col = field_to_csv_mapping[k.to_s]
      error_columns[original_col] = v
    end
    error_columns
  end
end