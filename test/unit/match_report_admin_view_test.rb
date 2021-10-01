require_relative '../test_helper'

class MatchReportAdminViewTest < ActiveSupport::TestCase
  def test_validations
    match_report_admin_view = MatchReportAdminView.first
    match_report_admin_view.update_attribute(:program, nil)
    assert_false match_report_admin_view.valid?
    assert_equal ["can't be blank"],  match_report_admin_view.errors.messages[:program]

    match_report_admin_view = MatchReportAdminView.second
    match_report_admin_view.update_attribute(:admin_view, nil)
    assert_false match_report_admin_view.valid?
    assert_equal ["can't be blank"],  match_report_admin_view.errors.messages[:admin_view]

    match_report_admin_view = MatchReportAdminView.third
    match_report_admin_view.update_attribute(:section_type, nil)
    assert_false match_report_admin_view.valid?
    assert_equal ["can't be blank"],  match_report_admin_view.errors.messages[:section_type]

    match_report_admin_view = MatchReportAdminView.fourth
    match_report_admin_view.update_attribute(:role_type, nil)
    assert_false match_report_admin_view.valid?
    assert_equal ["can't be blank"],  match_report_admin_view.errors.messages[:role_type]
  end

  def test_belongs_to_program
    assert MatchReportAdminView.first.program.present?
  end

  def test_belongs_to_admin_view
    assert MatchReportAdminView.first.admin_view.present?
  end

  def test_uniqueness_of
    mrav1 = MatchReportAdminView.first
    mrav2 = MatchReportAdminView.second
    mrav2.update_attributes(role_type: mrav1.role_type, section_type: mrav1.section_type, program_id: mrav1.program_id)
    assert_equal ["has already been taken"],  mrav2.errors.messages[:role_type]
  end
  
end