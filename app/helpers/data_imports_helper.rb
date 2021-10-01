module DataImportsHelper

  def data_import_status_display_text(data_import)
    case data_import.status
    when DataImport::Status::SUCCESS
      content_tag(:strong, "feature.data_imports.label.success".translate, class: "text-navy")
    when DataImport::Status::FAIL
      content_tag(:strong, "feature.data_imports.label.failed".translate, class: "text-danger")
    when DataImport::Status::SKIPPED
      content_tag(:strong, "feature.data_imports.label.skipped".translate, class: "text-muted")
    else
      "feature.data_imports.label.unknown".translate
    end
  end

  def additional_information_text(summary)
    case summary.status
    when DataImport::Status::SUCCESS
      "feature.data_imports.content.success_info_v1".translate(created_count: summary.created_count, updated_count: summary.updated_count, suspended_count: summary.suspended_count)
    when DataImport::Status::FAIL
      # TODO_FEED_MIGRATOR_CONTENT_GLOBALIZATION
      summary.failure_message.gsub("\n", "<br />").html_safe
    when DataImport::Status::SKIPPED
      "feature.data_imports.content.skipped_info".translate
    else
      content_tag(:i, "feature.data_imports.content.info_not_available".translate, class: "text-muted")
    end
  end

  def source_file_created_at(file_name)
    ds = file_name.match(/(\d+).*/)[1]
    time = Time.utc(ds[0..3].to_i, ds[4..5].to_i, ds[6..7].to_i, ds[8..9].to_i, ds[10..11].to_i, ds[12..13].to_i).in_time_zone
    formatted_time_in_words(time, no_ago: true)
  end

end