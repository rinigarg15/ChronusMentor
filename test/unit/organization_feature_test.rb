require_relative './../test_helper.rb'

class OrganizationFeatureTest < ActiveSupport::TestCase
  def test_organization_and_name_required
    assert_multiple_errors([{:field => :organization}, {:field => :feature}]) do
      OrganizationFeature.create!
    end
  end

  def test_create_success
    OrganizationFeature.destroy_all
    org_feature = ""
    prog_feature = ""
    assert_difference 'OrganizationFeature.count' do
      org_feature = OrganizationFeature.create!(:organization_id => programs(:org_primary).id, :feature => Feature.find_by(name: FeatureName::ANSWERS))
    end
    assert org_feature.enabled?

    assert_difference 'OrganizationFeature.count' do
      prog_feature = OrganizationFeature.create!(:organization_id => programs(:albers).id, :feature => Feature.find_by(name: FeatureName::ANSWERS), :enabled => false)
    end
    assert org_feature.enabled?
    assert_false prog_feature.enabled?
  end

  def test_name_is_unique_for_organization
    OrganizationFeature.destroy_all
    assert_difference 'OrganizationFeature.count' do
      @feature = OrganizationFeature.create!(:organization_id => programs(:org_primary).id, :feature => Feature.find_by(name: FeatureName::ANSWERS))
    end

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :feature do
      OrganizationFeature.create!(:organization_id => programs(:org_primary).id, :feature => Feature.find_by(name: FeatureName::ANSWERS))
    end
  end

  def test_after_create_and_after_destroy_offer_mentoring
    mentor= users(:f_mentor)
    assert_false mentor.can_offer_mentoring?

    assert_difference 'RolePermission.count', 6 do
      OrganizationFeature.create!(:organization_id => programs(:org_primary).id, :feature => Feature.find_by(name: FeatureName::OFFER_MENTORING))
    end

    assert_equal RoleConstants::MENTOR_NAME, RolePermission.last.role.name
    assert_equal "offer_mentoring", RolePermission.last.permission.name
    assert mentor.reload.can_offer_mentoring?


    assert_difference 'RolePermission.count', -6 do
      OrganizationFeature.last.update_attributes(:enabled => false)
    end

    assert_false mentor.reload.can_offer_mentoring?
  end

  def test_after_save_update_email_dependencies
    programs = programs(:org_primary).programs
    email_uids_to_enable = FeatureName.dependent_emails[FeatureName::CALENDAR_SYNC][:enabled].collect{|mailer|mailer.mailer_attributes[:uid]}
    programs.each do |program|
      Mailer::Template.expects(:enable_mailer_templates_for_uids).with(program, email_uids_to_enable)
    end
    OrganizationFeature.where(:organization_id => programs(:org_primary).id, :feature => Feature.find_by(name: FeatureName::CALENDAR_SYNC)).first.destroy
    feature = OrganizationFeature.create!(:organization_id => programs(:org_primary).id, :feature => Feature.find_by(name: FeatureName::CALENDAR_SYNC))
    programs.each do |program|
      Mailer::Template.expects(:enable_mailer_templates_for_uids).with(program, email_uids_to_enable).never
    end
    feature.update_attributes!(enabled: false)
    Mailer::Template.expects(:enable_mailer_templates_for_uids).with(programs(:albers), email_uids_to_enable).once
    OrganizationFeature.create!(:organization_id => programs(:albers).id, :feature => Feature.find_by(name: FeatureName::CALENDAR_SYNC))
  end

  def test_handle_feature_dependencies
    program = programs(:org_primary)
    feature = OrganizationFeature.create!(organization_id: program.id, feature: Feature.find_by(name: FeatureName::MENTOR_TO_MENTEE_MATCHING))
    organization = feature.organization
    organization.expects(:handle_feature_dependency_mentor_to_mentee_matching).with(false)
    feature.update_attributes(enabled: false)
    organization.expects(:handle_feature_dependency_mentor_to_mentee_matching).with(true)
    feature.update_attributes(enabled: true)
  end

end
