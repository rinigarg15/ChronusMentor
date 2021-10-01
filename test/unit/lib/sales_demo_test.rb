require_relative './../../test_helper.rb'

class SalesDemoTest < ActionView::TestCase
  def test_schema_changes_from_existing_for_sales_populator
    tables_to_check = [ActivityLog, AdminMessage, AdminMessages::Receiver, AdminViewColumn, AdminView, CalendarSetting, CampaignManagement::AbstractCampaign, CampaignManagement::AbstractCampaignMessage, CampaignManagement::CampaignEmail, CampaignManagement::CampaignMessageAnalytics, Ckeditor::Asset, Connection::Activity, Connection::Membership, ConnectionMembershipStateChange, CustomizedTerm, Education, Experience, Feature, Forum, GroupCheckin, GroupClosureReason, Group, GroupStateChange, Mailer::Template, Manager, MatchConfig, MeetingRequest, Meeting, MemberMeetingResponse, MemberMeeting, Member, MembershipRequest, MentoringModel, MentoringModel::Activity, MentoringModel::Goal, MentoringModel::GoalTemplate, MentoringModel::Link, MentoringModel::Milestone, MentoringModel::MilestoneTemplate, MentoringModel::Task, MentoringModel::TaskTemplate, NotificationSetting, ObjectPermission, ObjectRolePermission, OrganizationFeature, Organization, Page, Page::Translation, Permission, Post, ProfileAnswer, ProfilePicture, ProfileQuestion, ProgramInvitation, Program, Publication, RecentActivity, Resource, ResourcePublication, Role, RolePermission, RoleQuestion, RoleQuestionPrivacySetting, RoleResource, Scrap, Scraps::Receiver, Section, SecuritySetting, Survey, SurveyAnswer, SurveyQuestion, Topic, User, UserSetting, UserStateChange]
    ignore_translates_check = [Page]

    new_total_column_details = {}
    tables_to_check.each do |table|
      table_column_details = {}
      table.columns_hash.each {|k,v| table_column_details[k] = v.type }
      if table.translates? && !table.in?(ignore_translates_check)
        translated_attrs = table.translated_attribute_names.map(&:to_s)
        table.translation_class.columns_hash.each do |k, v|
          table_column_details[k] = v.type if k.in? translated_attrs
        end
      end
      new_total_column_details[table.name] = table_column_details
    end

    old_new_total_column_details = YAML::load_file("#{Rails.root}/test/sales_demo_fixtures/sales_data_column_details.yml")
    tables_to_check.each do |table|
      old_table_column_details = old_new_total_column_details[table.name]
      new_table_column_details = new_total_column_details[table.name]
      assert_equal_unordered old_table_column_details.keys, new_table_column_details.keys
      old_table_column_details.each do |old_column, old_column_datatype|
        assert_equal old_column_datatype, new_table_column_details[old_column], "datatype for #{old_column} column has been modified to table: #{table.name}, Check whether sales populator working properly"
      end
    end
  end
end