require_relative './../../test_helper.rb'

class Report::AlertTest < ActiveSupport::TestCase
  def setup
    super
    @program = programs(:albers)
    @view = @program.abstract_views.first
    @section = @program.report_sections.create(title: "Users", description: "All users metrics")
    @metric = @section.metrics.create(title: "pending users", description: "see pending users counts", abstract_view_id: @view.id)
    @alert = @metric.alerts.create(description: "Some Description", filter_params: "", operator: Report::Alert::OperatorType::LESS_THAN, target: 10)
  end

  def test_validations
    alert = Report::Alert.new
    assert !alert.valid?
    assert_equal(["can't be blank"], alert.errors[:description])
    assert_equal(["can't be blank", "is not included in the list"], alert.errors[:operator])
    assert_equal(["can't be blank"], alert.errors[:target])
    assert_equal(["can't be blank"], alert.errors[:metric_id])
  end

  def test_associations
    assert_equal @alert.metric, @metric
    assert_no_difference "Report::Metric.count" do
      assert_no_difference "Program.count" do
        @alert.destroy
      end
    end
  end

  def test_check_alert_count_for_signed_up_on
    admin_view = @program.admin_views.where(title: "All Users").first
    metric = @section.metrics.create(title: "All Users", description: "All Users Count", abstract_view_id: admin_view.id)

    alert = metric.alerts.create(description: "Some Description", filter_params: { cjs_alert_filter_params_0: { name: FilterUtils::AdminViewFilters::FILTERS[FilterUtils::AdminViewFilters::SIGNED_UP_ON.to_sym][:value], operator: FilterUtils::DateRange::IN_LAST, value: "2" } }.to_yaml.gsub(/--- \n/, ""), operator: Report::Alert::OperatorType::GREATER_THAN, target: 0)
    assert_equal 1, admin_view.count(alert)

    alert.update_attributes(filter_params: { cjs_alert_filter_params_0: { name: FilterUtils::AdminViewFilters::FILTERS[FilterUtils::AdminViewFilters::SIGNED_UP_ON.to_sym][:value], operator: FilterUtils::DateRange::BEFORE_LAST, value: "2" } }.to_yaml.gsub(/--- \n/, ""))
    assert_equal 0, admin_view.count(alert)
  end

  def test_send_alert_mails_all_active_admin
    alert = report_alerts(:report_alert_1)
    program = programs(:albers)

    MentorRequest.expects(:get_mentor_requests_search_count).at_least(0).returns(0)
    assert_equal [], program.get_report_alerts_to_notify

    alert.update_attribute(:operator, Report::Alert::OperatorType::GREATER_THAN)
    program.reload

    program.admin_users.each do |admin|
      if admin.member.admin?
        ChronusMailer.expects(:organization_report_alert).times(1).with(admin.member, kind_of(Hash)).returns(stub(:deliver_now))
      else
        ChronusMailer.expects(:program_report_alert).times(1).with(admin, [report_alerts(:report_alert_1)]).returns(stub(:deliver_now))
      end
    end
    Report::Alert.send_alert_mails
  end

  def test_send_alert_mails_one_active_admin
    MentorRequest.expects(:get_mentor_requests_search_count).at_least(0).returns(0)
    alert = report_alerts(:report_alert_1)
    program = programs(:albers)
    assert_equal [], program.get_report_alerts_to_notify

    alert.update_attribute(:operator, Report::Alert::OperatorType::GREATER_THAN)
    program.reload

    admin_user1 = program.admin_users.first
    admin_user2 = program.admin_users.last
    admin_user1.update_attribute(:state, "suspended")
    program.reload
    admin_user1.member.update_attributes!(admin: false)
    admin_user2.member.update_attributes!(admin: false)
    ChronusMailer.expects(:program_report_alert).times(1).with(admin_user2, [report_alerts(:report_alert_1)]).returns(stub(:deliver_now))
    ChronusMailer.expects(:program_report_alert).times(0).with(admin_user1, [report_alerts(:report_alert_1)]).returns(stub(:deliver_now))

    Report::Alert.send_alert_mails
  end

  def test_send_alert_mails_no_matching_alert
    MentorRequest.expects(:get_mentor_requests_search_count).at_least(0).returns(0)
    alert = report_alerts(:report_alert_1)
    program = programs(:albers)
    assert_equal [], program.get_report_alerts_to_notify
    ChronusMailer.expects(:report_alert).times(0).returns(stub(:deliver_now))

    Report::Alert.send_alert_mails
  end

  def test_can_notify_alert
    alert = report_alerts(:report_alert_1)
    assert_equal Report::Alert::OperatorType::LESS_THAN, alert.operator
    assert_equal 10, alert.target

    metric = alert.metric

    alert.update_attribute(:target, metric.count - 1)
    alert.reload
    assert_false alert.can_notify_alert?
    alert.update_attribute(:target, metric.count)
    alert.reload
    assert_false alert.can_notify_alert?
    alert.update_attribute(:target, metric.count + 1)
    alert.reload
    assert alert.can_notify_alert?

    alert.update_attribute(:operator, Report::Alert::OperatorType::GREATER_THAN)
    alert.update_attribute(:target, metric.count - 1)
    alert.reload
    assert alert.can_notify_alert?
    alert.update_attribute(:target, metric.count)
    alert.reload
    assert_false alert.can_notify_alert?
    alert.update_attribute(:target, metric.count + 1)
    alert.reload
    assert_false alert.can_notify_alert?

    alert.update_attribute(:operator, Report::Alert::OperatorType::EQUAL)
    alert.update_attribute(:target, metric.count - 1)
    alert.reload
    assert_false alert.can_notify_alert?
    alert.update_attribute(:target, metric.count)
    alert.reload
    assert alert.can_notify_alert?
    alert.update_attribute(:target, metric.count + 1)
    alert.reload
    assert_false alert.can_notify_alert?
  end
end