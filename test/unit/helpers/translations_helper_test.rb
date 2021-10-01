require_relative './../../test_helper.rb'

class TranslationsHelperTest < ActionView::TestCase
  include TranslationsHelper

  def test_get_translations_dropdown_options
    content = get_translations_dropdown_options(:de)
    assert_equal 2, content.count

    assert_equal "Export to csv", content.first[:label]
    assert_equal "/translations/export_csv?locale=de", content.first[:url]
    assert_equal "translations_csv_export", content.first[:btn_class_name]

    assert_equal "Import from csv", content.second[:label]
    assert_equal "javascript:void(0)", content.second[:url]
    assert_equal "modal", content.second[:data][:toggle]
    assert_equal "#cjs_translations_import_modal", content.second[:data][:target]
  end

  def test_get_ckeditor_type_class_for_inline_tool
    assert_nil get_ckeditor_type_class_for_inline_tool
    assert_equal "cjs_ckeditor_dont_register_for_tags_warning", get_ckeditor_type_class_for_inline_tool({category: LocalizableContent::CAMPAIGN, klass: Mailer::Template.name})
    assert_equal "cjs_ckeditor_dont_register_for_tags_warning cjs_ckeditor_dont_register_for_insecure_content", get_ckeditor_type_class_for_inline_tool({category: LocalizableContent::MENTORING_MODEL, klass: MentoringModel::FacilitationTemplate.name})
  end


end