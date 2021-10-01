require_relative './../../test_helper.rb'

class AbstractRequestsHelperTest < ActionView::TestCase
  def test_collapsible_filter_view_field_filter_all_roles
    filter_field = AbstractRequest::Filter::TO_ME
    filter = { all: true, by_me: true, to_me: true }
    options = { js_action: "return MentorOffers.applyFilters();" }
    stub_request_parameters(controller: "mentor_requests")
    content = collapsible_filter_view_field_filter(filter_field, filter, options)
    set_response_text(content)
    assert_select "div.filter_item" do
      assert_select "div.panel" do
        assert_select "label.radio", text: "Requests received" do
          assert_select "input#filter_me[type=radio][value=me][checked=checked]"
        end

        assert_select "label.radio", text: "Requests initiated" do
          assert_select "input#filter_by_me[type=radio][value=by_me]"
        end

        assert_select "label.radio", text: "All requests" do
          assert_select "input#filter_all[type=radio][value=all]"
        end
      end
    end
  end

  def test_collapsible_filter_view_field_filter_all_roles_offers
    filter_field = AbstractRequest::Filter::TO_ME
    filter = { all: true, by_me: true, to_me: true }
    options = { js_action: "return MentorOffers.applyFilters();", entity: "mentor_offer" }
    stub_request_parameters(controller: "mentor_offers")
    content = collapsible_filter_view_field_filter(filter_field, filter, options)
    set_response_text(content)
    assert_select "div.filter_item" do
      assert_select "div.panel" do
        assert_select "label.radio", text: "Offers received" do
          assert_select "input#filter_me[type=radio][value=me][checked=checked]"
        end

        assert_select "label.radio", text: "Offers initiated" do
          assert_select "input#filter_by_me[type=radio][value=by_me]"
        end

        assert_select "label.radio", text: "All offers" do
          assert_select "input#filter_all[type=radio][value=all]"
        end
      end
    end
  end

  def test_collapsible_filter_view_field_filter_dual_role_end_user
    filter_field = AbstractRequest::Filter::BY_ME
    filter = { all: false, by_me: true, to_me: true }
    options = { js_action: "return MentorOffers.applyFilters();" }
    stub_request_parameters(controller: "mentor_requests")
    content = collapsible_filter_view_field_filter(filter_field, filter, options)
    set_response_text(content)
    assert_select "div.filter_item" do
      assert_select "div.panel" do
        assert_select "label.radio", text: "Requests received" do
          assert_select "input#filter_me[type=radio][value=me]"
        end

        assert_select "label.radio", text: "Requests initiated" do
          assert_select "input#filter_by_me[type=radio][value=by_me][checked=checked]"
        end

        assert_select "label.radio", text: "All requests", count: 0 do
          assert_select "input#filter_all[type=radio][value=all]"
        end
      end
    end
  end

  def test_collapsible_filter_view_field_filter_dual_role_admin
    filter_field = AbstractRequest::Filter::ALL
    filter = { all: true, by_me: true, to_me: false }
    options = { js_action: "return MentorOffers.applyFilters();" }
    stub_request_parameters(controller: "mentor_requests")
    content = collapsible_filter_view_field_filter(filter_field, filter, options)
    set_response_text(content)
    assert_select "div.filter_item" do
      assert_select "div.panel" do
        assert_select "label.radio", text: "Requests received", count: 0 do
          assert_select "input#filter_me[type=radio][value=me]"
        end

        assert_select "label.radio", text: "Requests initiated" do
          assert_select "input#filter_by_me[type=radio][value=by_me]"
        end

        assert_select "label.radio", text: "All requests" do
          assert_select "input#filter_all[type=radio][value=all][checked=checked]"
        end
      end
    end
  end

  def test_get_rejection_reason_collection
    self.stubs(:_mentee).returns("mentee")
    self.stubs(:_mentees).returns("mentees")
    radio_button_texts = get_rejection_reason_collection(1)
    matching_text =[["Not the right match for this mentee", 1], ["Reached my limit and cannot take more mentees", 2], ["Busy at this time and cannot take a mentee for some time", 3], ["Other", 4]]
    assert_equal radio_button_texts, matching_text
  end
end
