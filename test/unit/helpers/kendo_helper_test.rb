require_relative './../../test_helper.rb'

class KendoHelperTest < ActionView::TestCase

  def test_include_kendo
    self.expects(:javascript_include_tag).with("kendo.all.min.js").once
    include_kendo
  end

  def test_kendo_operator_messages
    expected_output = {
      operators: {
        number: {
          eq: "Is equal to",
          neq: "Is not equal to",
          gte: "Is greater than or equal to",
          gt: "Is greater than",
          lte: "Is less than or equal to",
          lt: "Is less than"
        }
      }
    }
    assert_equal expected_output, kendo_operator_messages
  end

  def test_get_kendo_filterable_options
    choices_map = { "a" => { "b" => 1, "c" => 2 } }
    messages = { info: "", filter: "Filter", clear: "Clear", selectedItemsFormat: "" }

    assert_equal_hash( { multi: true, dataSource: choices_map["a"], messages: messages }, get_kendo_filterable_options("a", choices_map, extra: true))
    assert_equal_hash( { ui: "string", extra: true, messages: messages }, get_kendo_filterable_options("b", choices_map, extra: true))
    assert_equal_hash( { ui: "string", extra: false, messages: messages }, get_kendo_filterable_options("b", choices_map))
  end

  def test_kendo_custom_accessibilty_messages
    assert_equal_hash( {
      selectOperator: "Select operator.",
      filterBy: "Filter by",
    }, kendo_custom_accessibilty_messages)
  end

  def test_get_primary_checkbox_for_kendo_grid
    content = get_primary_checkbox_for_kendo_grid
    assert_select_helper_function "label.sr-only", content, text: "Select Fields to Display", for: "cjs_select_all_primary_checkbox"
    assert_select_helper_function "input[type='checkbox']#cjs_select_all_primary_checkbox", content

    content = get_primary_checkbox_for_kendo_grid("checkbox-no-1")
    assert_select_helper_function "label.sr-only", content, text: "Select Fields to Display", for: "checkbox-no-1"
    assert_select_helper_function "input[type='checkbox']#checkbox-no-1", content
  end

  def test_get_kendo_bulk_actions_box
    actions = [{
      label: "test label", url: "test url"
      }]
    result = get_kendo_bulk_actions_box(actions)
    assert_select_helper_function_block "div.btn-group.m-b.cur_page_info", result do
      assert_select "a.dropdown-toggle"
      assert_select "ul.dropdown-menu" do
        assert_select "li" do
          assert_select "a[href='test url']", text: "test label"
        end
      end
    end
  end

  def test_kendo_column_header_wrapper
    assert_select_helper_function "span.test_class.cjs_kendo_title_header", kendo_column_header_wrapper("Test Title", class: "test_class"), text: "Test Title"
  end
end