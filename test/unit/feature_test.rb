require_relative './../test_helper.rb'

class FeatureTest < ActiveSupport::TestCase
  def test_has_many_organization_features
    OrganizationFeature.destroy_all
    o = programs(:org_primary)
    feature = Feature.find_by(name: FeatureName::ARTICLES)
    other_feature = Feature.find_by(name: FeatureName::ANSWERS)

    assert feature.organization_features.blank?

    of = create_organization_feature(:feature => feature, :organization_id => o.id)
    create_organization_feature(:feature => other_feature, :organization_id => o.id)

    assert_equal [of], feature.reload.organization_features

    assert_difference "Feature.count", -1 do
      assert_difference "OrganizationFeature.count", -1 do
        feature.destroy
      end
    end
  end

  def test_create_default_features
    Feature.destroy_all
    assert_difference 'Feature.count', FeatureName.all.size do
      Feature.create_default_features
    end
  end

  def test_create_default_features_with_features_present
    assert_no_difference 'Feature.count' do
      Feature.create_default_features
    end
  end

  def test_check_uniqueness_of_feature_name
    feature = Feature.find_by(name: FeatureName::ARTICLES)
    assert feature.present?
    assert_raise(ActiveRecord::RecordInvalid) do
      Feature.create!(:name => FeatureName::ARTICLES)
    end

    feature = Feature.create!(:name => "Sample Feature")

    assert_match feature.name, "Sample Feature"
  end

  def test_handle_feature_dependency
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    set_features(program.reload, [FeatureName::MENTORING_CONNECTION_MEETING], false)
    program.reload

    Feature.handle_feature_dependency(program)

    program.reload
    assert program.has_feature?(FeatureName::MENTORING_CONNECTIONS_V2)
    assert program.has_feature?(FeatureName::MENTORING_CONNECTION_MEETING)
  end

  def test_handle_specific_feature_dependency
    program = programs(:albers)
    set_features(program.reload, [FeatureName::CONNECTION_PROFILE, FeatureName::BULK_MATCH], false)
    set_features(program.reload, [FeatureName::CALENDAR])
    assert program.has_feature?(FeatureName::CALENDAR)
    program.organization.enable_feature(FeatureName::CALENDAR)
    program.reload
    assert program.organization.reload.has_feature?(FeatureName::CALENDAR)

    Feature.handle_specific_feature_dependency(program)

    program.reload
    assert program.has_feature?(FeatureName::CONNECTION_PROFILE)
    assert program.has_feature?(FeatureName::MENTORING_CONNECTIONS_V2)
    assert_false program.has_feature?(FeatureName::CALENDAR)
    assert program.organization.reload.has_feature?(FeatureName::CALENDAR)
    assert_false program.has_feature?(FeatureName::BULK_MATCH)
    assert_false program.has_feature?(FeatureName::OFFER_MENTORING)

    # Even second degree dependent features should be enabled
    assert program.has_feature?(FeatureName::MENTORING_CONNECTION_MEETING)
    assert_false program.has_feature?(FeatureName::COACHING_GOALS)
  end

  def test_enable_disable_features_for_program
    program = programs(:albers)
    org = program.organization
    set_features(org.reload, [FeatureName::OFFER_MENTORING, FeatureName::BULK_MATCH], false)
    set_features(org.reload, [FeatureName::CALENDAR], true)
    program.reload
    org.reload
    [FeatureName::OFFER_MENTORING, FeatureName::BULK_MATCH].each do |feature_name|
      assert_false program.has_feature?(feature_name)
      assert_false org.has_feature?(feature_name)
    end
    [FeatureName::CALENDAR].each do |feature_name|
      assert program.has_feature?(feature_name)
      assert org.has_feature?(feature_name)
    end

    enabled_disabled_config = {
      enabled: [FeatureName::OFFER_MENTORING, FeatureName::BULK_MATCH],
      disabled: [FeatureName::CALENDAR]
    }
    Feature.enable_disable_features(program, enabled_disabled_config)
    program.reload
    org.reload
    # Program level features should be enabled only for program
    [FeatureName::BULK_MATCH, FeatureName::OFFER_MENTORING].each do |feature_name|
      assert program.has_feature?(feature_name)
      assert_false org.has_feature?(feature_name)
    end
  end

  def test_tandem_features_list_and_info
    assert_equal_unordered [FeatureName::ENHANCED_MEETING_SCHEDULER], FeatureName.tandem_features
    assert_equal_hash({FeatureName::CALENDAR_SYNC_V2 => [FeatureName::ENHANCED_MEETING_SCHEDULER]}, FeatureName.tandem_features_info)
  end

  def test_get_translate_hash
    prog_or_org = programs(:albers)
    assert_equal_hash({mentor_name_plural_uppercase: "Mentors", program_term_upcase: "Program", mentoring_term_downcase: "mentoring", career_development_term_upcase: "Career Development", mentoring_connection_name_upcase: "Mentoring Connection", meeting_term_uppercase: "Meeting", mentor_name_uppercase: "Mentor", mentee_name_uppercase: "Student"}, FeatureName::Titles.get_translate_hash(prog_or_org))
    assert_equal_hash({default: "", mentor_name: "mentor", mentee_name: "student", mentee_name_plural: "students", mentor_name_plural: "mentors", mentoring_connection_name: "mentoring connection", mentoring_connection_name_plural: "mentoring connections", program: "program", mentoring_term_downcase: "mentoring", meeting_term_downcase: "meeting"}, FeatureName::Descriptions.get_translate_hash(prog_or_org))
  end

  def test_enable_disable_features_for_organization
    program = programs(:albers)
    org = program.organization
    set_features(org.reload, [FeatureName::OFFER_MENTORING, FeatureName::BULK_MATCH], false)
    set_features(org.reload, [FeatureName::CALENDAR], true)
    org.reload
    [FeatureName::OFFER_MENTORING, FeatureName::BULK_MATCH].each do |feature_name|
      assert_false org.has_feature?(feature_name)
    end
    [FeatureName::CALENDAR].each do |feature_name|
      assert org.has_feature?(feature_name)
    end

    enabled_disabled_config = {
      enabled: [FeatureName::OFFER_MENTORING, FeatureName::BULK_MATCH],
      disabled: [FeatureName::CALENDAR]
    }
    Feature.enable_disable_features(org, enabled_disabled_config)
    org.reload
    # All features should be enabled
    [FeatureName::OFFER_MENTORING, FeatureName::BULK_MATCH].each do |feature_name|
      assert org.has_feature?(feature_name)
    end
    # All features should be disabled
    [FeatureName::CALENDAR].each do |feature_name|
      assert_false org.has_feature?(feature_name)
    end
  end

private

  def set_features(program, feature_names, enabled = true)
    feature_names.each do |feature_name|
      program.enable_feature(feature_name, enabled)
    end
  end
end
