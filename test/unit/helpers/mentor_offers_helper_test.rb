require_relative './../../test_helper.rb'

class MentorOffersHelperTest < ActionView::TestCase
  def test_get_mentor_offer_filters
    assert_equal_hash({ all: true, by_me: false, to_me: false }, get_mentor_offer_filters(users(:f_admin)))
    assert_equal_hash({ all: false, by_me: false, to_me: false }, get_mentor_offer_filters(users(:f_user)))
    assert_equal_hash({ all: false, by_me: true, to_me: false }, get_mentor_offer_filters(users(:f_mentor)))
    assert_equal_hash({ all: false, by_me: false, to_me: true }, get_mentor_offer_filters(users(:f_student)))
    assert_equal_hash({ all: false, by_me: true, to_me: true }, get_mentor_offer_filters(users(:f_mentor_student)))
    assert_equal_hash({ all: true, by_me: true, to_me: false }, get_mentor_offer_filters(users(:ram)))
  end

  def test_mentor_offers_bulk_actions
    @filter_params = {}
    @filter_params["status"] = MentorOffer::Status::STATE_TO_STRING[MentorOffer::Status::PENDING]
    bulk_actions_output = mentor_offers_bulk_actions(true)
    set_response_text(bulk_actions_output)
    assert_select "a.btn.dropdown-toggle[data-toggle=\"dropdown\"]", {text: "Actions Actions"} do
      assert_select "span.sr-only", {text: "Actions"}
    end
    assert_select "a#cjs_close_requests[title=\"\"]", {text: "Close Offers"} do
      assert_select "i.fa.fa-ban.fa-fw.m-r-xs"
    end
    assert_select "a#cjs_send_message_to_senders[title=\"\"]", {text: "Send Message to Senders"} do
      assert_select "i.fa.fa-envelope.fa-fw.m-r-xs"
    end
    assert_select "a#cjs_send_message_to_recipients[title=\"\"]", {text: "Send Message to Recipients"} do
      assert_select "i.fa.fa-envelope.fa-fw.m-r-xs"
    end
    assert_select "a.cjs_mentor_offer_export[title=\"\"]", {text: "Export as CSV"} do
      assert_select "i.fa.fa-download.fa-fw.m-r-xs"
    end
    @filter_params["status"] = MentorOffer::Status::STATE_TO_STRING[MentorOffer::Status::CLOSED]
    bulk_actions_output = mentor_offers_bulk_actions
    set_response_text(bulk_actions_output)
    assert_select "a#cjs_send_message_to_senders[title=\"\"]", {text: "Send Message to Senders"} do
      assert_select "i.fa.fa-envelope.fa-fw.m-r-xs"
    end
    assert_select "a#cjs_send_message_to_recipients[title=\"\"]", {text: "Send Message to Recipients"} do
      assert_select "i.fa.fa-envelope.fa-fw.m-r-xs"
    end
    assert_select "a.cjs_mentor_offer_export[title=\"\"]", {text: "Export as CSV"} do
      assert_select "i.fa.fa-download.fa-fw.m-r-xs"
    end
    bulk_actions_output = mentor_offers_bulk_actions(true)
    set_response_text(bulk_actions_output)
    assert_select "a#cjs_send_message_to_senders[title=\"\"]", {text: "Send Message to Senders"} do
      assert_select "i.fa.fa-envelope.fa-fw.m-r-xs"
    end
    assert_select "a#cjs_send_message_to_recipients[title=\"\"]", {text: "Send Message to Recipients"} do
      assert_select "i.fa.fa-envelope.fa-fw.m-r-xs"
    end
  end

  def test_get_tabs_for_mentor_offers_listing
    active_tab = MentorOffer::Status::STATE_TO_STRING[MentorOffer::Status::PENDING]
    label_tab_mapping = {
      "Pending" => MentorOffer::Status::STATE_TO_STRING[MentorOffer::Status::PENDING],
      "Accepted" => MentorOffer::Status::STATE_TO_STRING[MentorOffer::Status::ACCEPTED],
      "Declined" => MentorOffer::Status::STATE_TO_STRING[MentorOffer::Status::REJECTED],
      "Withdrawn" => MentorOffer::Status::STATE_TO_STRING[MentorOffer::Status::WITHDRAWN],
      "Closed" => MentorOffer::Status::STATE_TO_STRING[MentorOffer::Status::CLOSED]
    }
    expects(:get_tabs_for_listing).with(label_tab_mapping, active_tab, url: manage_mentor_offers_path, param_name: :status)
    get_tabs_for_mentor_offers_listing(active_tab)
  end
end
