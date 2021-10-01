require_relative './../../test_helper.rb'

class ProjectRequestsHelperTest < ActionView::TestCase
  include GroupsHelper

  def test_get_actions_for_pending_request
    project_request = ProjectRequest.create!(:message => "Hi", :sender_id => users(:f_student_pbe).id, :group_id => groups(:group_pbe_1).id, :program => programs(:pbe))

    stub_current_program(project_request.program)
    actions = actions_for_project_requests_listing(project_request)
    set_response_text actions

    assert_select "div.btn-group" do
      assert_select "a.dropdown-toggle"
      assert_select "ul.dropdown-menu" do
        assert_select "li" do
          assert_select "a.cjs_action_project_requests[data-url='/project_requests/fetch_actions'][data-request-type='1']"
          assert_select "a.cjs_reject_request.cjs_action_project_requests[data-url='/project_requests/fetch_actions'][data-request-type='2']"
        end
      end
    end
    assert_nil actions.match(/Go to Project/)
  end

  def test_project_requests_bulk_actions
    actions = project_requests_bulk_actions("ga_src", false)
    assert_select_helper_function_block "div.btn-group.cur_page_info", actions do
      assert_select "a.dropdown-toggle"
      assert_select "span.sr-only", text: "Actions"
      assert_select "ul.dropdown-menu" do
        assert_select "li" do
          assert_select "a#cjs_bulk_accept_request.cjs_bulk_action_project_requests", text: "Accept" do
            assert_select "i.fa-check"
          end
        end
        assert_select "li" do
          assert_select "a#cjs_bulk_reject_request.cjs_bulk_action_project_requests", text: "Reject" do
            assert_select "i.fa-times"
          end
        end
      end
    end
  end

  def test_show_find_new_project
    assert show_find_new_project?(users(:f_admin_pbe), nil)
    assert show_find_new_project?(users(:f_student_pbe), nil)
    assert show_find_new_project?(users(:f_student_pbe), {})

    users(:f_student_pbe).groups.first.membership_of(users(:f_student_pbe)).update_attributes!(owner: true)
    assert_false show_find_new_project?(users(:f_student_pbe), nil)
    assert_false show_find_new_project?(users(:f_student_pbe), {})
    assert show_find_new_project?(users(:f_student_pbe), {view: "1"})
  end

  def test_get_reason_for_project_request_non_acceptance
    project_request = ProjectRequest.first
    project_request.update_attributes!(status: ProjectRequest::Status::REJECTED)
    label = "Reason for rejection"
    response_text = "Request text"
    options = { heading_tag: :h4, class: "m-t-xs m-b-xs" }

    project_request.update_attributes!(response_text: response_text)
    expects(:profile_field_container_wrapper).with(label, response_text, options)
    project_request.update_attributes!(response_text: response_text)
    get_reason_for_project_request_non_acceptance(project_request)
    project_request.update_attributes!(status: ProjectRequest::Status::WITHDRAWN)

    label = "Reason for withdrawal"
    project_request.update_attributes!(response_text: nil)
    expects(:profile_field_container_wrapper).with(label, content_tag(:i, "common_text.Not_specified".translate), options)
    get_reason_for_project_request_non_acceptance(project_request)
  end

  def test_get_reject_or_withdraw_project_request_messages_hash
    expects(:get_reject_project_request_messages_hash).with(1)
    get_reject_or_withdraw_project_request_messages_hash(AbstractRequest::Status::REJECTED, 1)
    expects(:get_withdraw_project_request_messages_hash)
    get_reject_or_withdraw_project_request_messages_hash(AbstractRequest::Status::WITHDRAWN, 1)
  end

  def test_get_withdraw_project_request_messages_hash
    assert_equal ({
      modal_header: "Withdraw Request",
      placeholder_for_reason: "Enter a reason for withdrawing the project request.",
      label_for_reason: "Reason for withdrawal",
      submit_text: "Withdraw Request"
    }), send(:get_withdraw_project_request_messages_hash)
  end

  def test_get_reject_project_request_messages_hash
    assert_equal ({
      modal_header: "Reject Request",
      placeholder_for_reason: "Enter a reason for rejecting the project request.",
      label_for_reason: "Reason for rejection",
      submit_text: "Reject Request"
    }), send(:get_reject_project_request_messages_hash, 1)
    assert_equal ({
      modal_header: "Reject Requests",
      placeholder_for_reason: "Enter a reason for rejecting the project requests.",
      label_for_reason: "Reason for rejection",
      submit_text: "Reject Requests"
    }), send(:get_reject_project_request_messages_hash, 2)
  end

  def test_get_withdraw_project_request_action_button
    project_request = ProjectRequest.first
    project_request.stubs(:active?).returns(false)
    assert_nil get_withdraw_project_request_action_button(project_request, "ga_src")

    project_request.stubs(:active?).returns(true)
    expects(:get_project_request_action).with(AbstractRequest::Status::WITHDRAWN, additional_class: "cjs_action_project_requests cjs_withdraw_request m-t-sm", data: { id: project_request.id }, ga_src: "ga_src").returns("withdraw_action")
    expects(:dropdown_buttons_or_button).with(["withdraw_action"])
    get_withdraw_project_request_action_button(project_request, "ga_src")
  end

  def test_get_project_request_action
    type = AbstractRequest::Status::ACCEPTED
    expects(:append_text_to_icon).with("fa fa-check", "Accept").returns("label")
    assert_equal ({
      label: "label",
      url: "javascript:void(0)",
      class: "class_name",
      id: "id",
      additional_class: "additional_class_name",
      data: { url: fetch_actions_project_requests_path(src: "ga_src"), request_type: type, key: "value" }
    }), get_project_request_action(type, { ga_src: "ga_src", class: "class_name", additional_class: "additional_class_name", id: "id", data: { key: "value" } })
  end

  def test_get_tabs_for_project_requests_listing
    active_tab = ProjectRequest::Status::STATE_TO_STRING[ProjectRequest::Status::NOT_ANSWERED]
    label_tab_mapping = {
      "Pending"=>ProjectRequest::Status::STATE_TO_STRING[ProjectRequest::Status::NOT_ANSWERED],
      "Accepted"=>ProjectRequest::Status::STATE_TO_STRING[ProjectRequest::Status::ACCEPTED],
      "Rejected"=>ProjectRequest::Status::STATE_TO_STRING[ProjectRequest::Status::REJECTED],
      "Withdrawn"=>ProjectRequest::Status::STATE_TO_STRING[ProjectRequest::Status::WITHDRAWN],
      "Closed"=>ProjectRequest::Status::STATE_TO_STRING[ProjectRequest::Status::CLOSED]
    }
    expects(:get_tabs_for_listing).with(label_tab_mapping, active_tab, url: manage_project_requests_path, param_name: :status)
    get_tabs_for_project_requests_listing(active_tab)
  end

  def test_get_search_filter_for_project_requests
    expects(:construct_input_group).times(0)
    expects(:get_go_button_for_project_request_filter).times(0)
    get_search_filter_for_project_requests(:requestor, {requestor: "abc"}, false, false, skip_go_button: true)

    expects(:construct_input_group)
    expects(:get_go_button_for_project_request_filter)
    get_search_filter_for_project_requests(:requestor, {requestor: "abc"}, false, false)
  end

  private
  def _Mentoring_Connection
    "Project"
  end

  def _mentoring_connection
    "project"
  end
end
