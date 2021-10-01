module KendoHelper

  def include_kendo
    javascript_include_tag "kendo.all.min.js"
  end

  def kendo_operator_messages
    {
      operators: {
        number: {
          eq: 'feature.survey.kendo_filter.operators_number.messages.eq'.translate,
          neq: 'feature.survey.kendo_filter.operators_number.messages.neq'.translate,
          gte: 'feature.survey.kendo_filter.operators_number.messages.gte'.translate,
          gt: 'feature.survey.kendo_filter.operators_number.messages.gt'.translate,
          lte: 'feature.survey.kendo_filter.operators_number.messages.lte'.translate,
          lt: 'feature.survey.kendo_filter.operators_number.messages.lt'.translate
        }
      }
    }
  end

  def get_kendo_filterable_options(field_name, choices_map, non_choice_filtering_options = {})
    if choices_map[field_name].present?
      { multi: true, dataSource: choices_map[field_name] }
    else
      { ui: 'string', extra: false }.merge!(non_choice_filtering_options)
    end.merge!(messages: kendo_filterable_messages)
  end

  def kendo_custom_accessibilty_messages
    {
      selectOperator: "feature.survey.survey_report.filters.label.select_operator_label".translate,
      filterBy: "feature.admin_view.kendo_filter.custom_accessibility_messages.filter_by".translate
    }
  end

  def get_primary_checkbox_for_kendo_grid(checkbox_id = "cjs_select_all_primary_checkbox")
    primary_checkbox_label = "<label class='sr-only' for='#{checkbox_id}'>#{"feature.admin_view.header.Select_Fields".translate}</label>".html_safe
    "<input type='checkbox' id='#{checkbox_id}'></input>".html_safe + primary_checkbox_label
  end

  def get_kendo_bulk_actions_box(bulk_actions)
    build_dropdown_button("display_string.Actions".translate, bulk_actions, btn_group_btn_class: "btn-white btn", btn_class: "m-b cur_page_info has-below-2", is_not_primary: true)
  end

  def kendo_column_header_wrapper(title, options={})
    options[:class] = options[:class].to_s + " cjs_kendo_title_header"
    content_tag(:span, title, options)
  end

  private

  def kendo_filterable_messages
    {
      info: '',
      filter: 'feature.survey.responses.kendo.filters.button_text.filter'.translate,
      clear: 'feature.survey.responses.kendo.filters.button_text.clear'.translate,
      selectedItemsFormat: ''
    }
  end

end