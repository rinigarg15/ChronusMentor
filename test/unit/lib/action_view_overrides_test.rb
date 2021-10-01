require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/application_helper"

class ActionViewOverridesTest < ActionView::TestCase
  include WillPaginate::ViewHelpers

  def setup
    super
    helper_setup
  end

  def test_page_entries_info_with_single_page_collection
    content = page_entries_info(('a'..'d').to_a.paginate(page: 1, per_page: 5), entries_name: "strings")
    assert_equal "Displaying <b>all 4</b> strings", content

    content = page_entries_info(('a'..'d').to_a.paginate(page: 1, per_page: 5), short_display: true, entries_name: "Films")
    assert_equal "Films <b>1 - 4</b> of <b>4</b>", content

    content = page_entries_info([].paginate(page: 1, per_page: 5), short_display: true)
    assert_equal "No Entries found", content

    array = ('a'..'z').to_a
    content = page_entries_info(array.paginate(page: 2, per_page: 5), short_display: true, entries_name: "Film")
    assert_equal %{Film <b>6 - 10</b> of <b>26</b>}, content

    content = page_entries_info(array.paginate(page: 7, per_page: 4), entries_name: "strings")
    assert_equal %{Displaying strings <b>25 - 26</b> of <b>26</b> in total}, content

    # For elasticsearch
    collection = User.get_filtered_users("mentor", match_fields: ["name_only", "email"])
    content = page_entries_info(collection.paginate(page: 2, per_page: 5), short_display: true, entries_name: "Users")
    assert_equal %{Users <b>6 - 10</b> of <b>11</b>}, content
    collection = User.get_filtered_users("mentor", match_fields: ["name_only", "email"])
    content = page_entries_info(collection.paginate(page: 3, per_page: 5), short_display: true, entries_name: "Users")
    assert_equal %{Users <b>11 - 15</b> of <b>11</b>}, content
  end

  def test_url_for_override_for_scroll_to
    assert_equal "/users/1", url_for(controller: 'users', action: 'show', id: 1)
    assert_equal "/users/1?scroll_to=profile", url_for(controller: 'users', action: 'show', id: 1, anchor: 'profile')
    assert_equal "/users/1?scroll_to=profile", url_for(controller: 'users', action: 'show', id: 1, scroll_to: 'profile')
  end

  def test_mail_to_overrides
    assert_select_helper_function("a[href='mailto:test@example.com']", mail_to("test@example.com"), text: "test@example.com")
    assert_select_helper_function("a[href='mailto:reply+12345+abcd@example.com']", mail_to("reply+12345+abcd@example.com"), text: "reply+12345+abcd@example.com")
    assert_select_helper_function("a[href='mailto:reply+12345+%20abcd@example.com']", mail_to("reply+12345+ abcd@example.com"), text: "reply+12345+ abcd@example.com")

    assert_gem_version "actionview", "5.1.4", "Yahoo mail client doesn't have the ability to decode the email address in mail_to. In reply url (reply-stage+1234+3edqy9q5@m.chronus.com) we pass "+" which will be encoded in mail_to. So when user tries to reply using mail_to link then mail won't get deliever"
  end
end