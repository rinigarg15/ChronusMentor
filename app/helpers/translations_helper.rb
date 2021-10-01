module TranslationsHelper
  
  def get_translations_dropdown_options(second_locale)
    actions = [{label: "feature.translations.label.export".translate, url: export_csv_translations_path(locale: second_locale), btn_class_name: "translations_csv_export"}]
    actions << {label: "feature.translations.label.import".translate, url: "javascript:void(0)", data: { toggle: "modal", target: "#cjs_translations_import_modal" }}
  end

  def get_ckeditor_type_class_for_inline_tool(object_details = {})
    if object_details[:category] == LocalizableContent::CAMPAIGN && object_details[:klass] == Mailer::Template.name
      get_ckeditor_type_classes(CampaignManagement::AbstractCampaign.name)
    elsif object_details[:category] == LocalizableContent::MENTORING_MODEL && object_details[:klass] == MentoringModel::FacilitationTemplate.name
      get_ckeditor_type_classes(MentoringModel::FacilitationTemplate.name)
    end
  end

end