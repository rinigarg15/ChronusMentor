require_relative '../test_helper'

class LanguageTest < ActiveSupport::TestCase

  def test_create_should_succeed
    assert_difference 'Language.count', +1 do
      Language.create!(
          :display_title    => 'Japanese',
          :title            => 'Japanesulu',
          :language_name    => 'ja',
          :enabled          => true
        )
    end
  end

  def test_observers_reindex_es
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [38]).once
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(Member, [38]).once
    language = languages(:hindi)
    language.update_attribute(:title, "Je")
  end

  def test_observers_sync_language_name
    language = languages(:hindi)
    assert_equal ["de"], language.organization_languages.pluck(:language_name).uniq

    language.update_attribute(:title, "Hindee")
    assert_equal ["de"], language.reload.organization_languages.pluck(:language_name).uniq

    language.update_attribute(:language_name, "es")
    assert_equal ["es"], language.reload.organization_languages.pluck(:language_name).uniq
  end

  def test_basic_validations
    language = Language.create
    errors = language.errors
    assert_equal 3, errors.size

    assert_equal ["can't be blank"], errors[:display_title]
    assert_equal ["can't be blank"], errors[:title]
    assert_equal ["can't be blank"], errors[:language_name]
  end

  def test_language_name_should_be_unique

    assert_difference 'Language.count' do
      create_language(:language_name => 'fr')
    end

    error = assert_raises ActiveRecord::RecordInvalid do
      create_language(:language_name => 'fr')
    end
    assert_equal 'Validation failed: Language name has already been taken', error.message
  end

  def test_language_name_should_not_be_reserved
    error = assert_raises ActiveRecord::RecordInvalid do
      create_language(:language_name => 'en')
    end
    assert_equal 'Validation failed: Language name is reserved', error.message
  end

  def test_scope_ordered
    create_language(:title => 'French', :language_name => 'fr')
    create_language(:title => 'Chinese', :language_name => 'ch')

    assert_equal ["Chinese", "French", "Hindi", "Telugu"], Language.ordered.collect(&:title)
  end

  def test_for_member
    member = members(:anna_univ_admin)
    language = languages('hindi')
    assert_nil member.member_language
    assert_equal :en, Language.for_member(member)

    assert member.admin?
    member.build_member_language(language: language)
    member.save!
    assert_equal :de, Language.for_member(member)

    member.stubs(:admin?).returns(false)
    assert_equal :en, Language.for_member(member)

    org_lang = create_organization_language(organization: member.organization)
    program1, program2 = member.programs
    assert_equal :de, Language.for_member(member)
    assert_equal :de, Language.for_member(member, program1)
    assert_equal :de, Language.for_member(member, program2)

    org_lang.send(:disable_for_program_ids, [program2.id])
    assert_equal :de, Language.for_member(member)
    assert_equal :de, Language.for_member(member, program1)
    assert_equal :en, Language.for_member(member, program2)
  end

  def test_set_for_member_on_change
    member = members(:f_student)

    member.build_member_language(:language => languages('hindi'))
    member.save!
    assert_equal :de, Language.for_member(member)

    assert_no_difference 'MemberLanguage.count' do # This should change the existing member-language
      check_for_delta_indexing(member, reset_delta: true) do
        Language.set_for_member(member, 'es')
      end
    end
    assert_equal :es, Language.for_member(member)
  end

  def test_set_for_member_when_setting_invalid_language
    member = members(:f_student)
    error = assert_raises ActiveRecord::RecordInvalid do
      check_for_delta_indexing(member, no_reindex: true) do
        Language.set_for_member(member, 'invalid-locale')
      end
    end
    assert_equal "Validation failed: Language can't be blank", error.message
  end

  def test_set_for_member_on_change_to_english
    member = members(:f_student)

    member.build_member_language(:language => languages('hindi'))
    member.save!
    assert_equal :de, Language.for_member(member)

    assert_difference 'MemberLanguage.count', -1 do # This should delete the hindi member language
      check_for_delta_indexing(member) do
        Language.set_for_member(member, 'en')
      end
    end
    assert_equal :en, Language.for_member(member.reload)
  end

  def test_for_english
    english = Language.for_english

    assert_equal 'English', english.title
    assert_nil       english.display_title
    assert_equal 'en',      english.language_name
  end

  def test_to_display_for_english
    english = Language.for_english
    assert_equal 'English', english.to_display
  end

  def test_to_display_for_non_english
    hindi  = languages(:hindi)
    telugu = languages(:telugu)

    assert_equal 'Hindi (Hindilu)',   hindi.to_display
    assert_equal 'Telugu (Telugulu)', telugu.to_display
  end

  def test_default
    english = Language.for_english
    hindi  = languages(:hindi)

    assert_equal true,  english.default?
    assert_equal false, hindi.default?
  end

  def test_for_valid_locale
    assert Language.valid_locale?("de", false, nil, nil, from_non_org: true)
    assert_false Language.valid_locale?("ed", false, nil, nil, from_non_org: true)
  end

  def test_supported_for
    admin_member = members(:f_admin)
    non_admin_member = members(:f_mentor)
    org = programs(:org_primary)
    org.enable_feature(FeatureName::LANGUAGE_SETTINGS)
    org.reload
    albers = programs(:albers)
    nwen = programs(:nwen)
    ProgramLanguage.destroy_all
    languages(:telugu).update_attributes!(enabled: false)
    organization_languages(:hindi).update_attributes!(enabled: OrganizationLanguage::EnabledFor::ADMIN)
    #super member should see all the languages
    languages = Language.supported_for(true, admin_member, albers)
    assert_equal [languages(:hindi), languages(:telugu)], languages

    #non super user admin member should see all the enabled languages
    assert_equal [languages(:hindi)], Language.supported_for(false, admin_member, albers)

    #non super user non admin member should see only the enabled languages with organization languages enabled in their programs
    assert_equal [], Language.supported_for(false, non_admin_member, albers)

    organization_languages(:hindi).update_attributes!(enabled: OrganizationLanguage::EnabledFor::ALL)
    organization_languages(:hindi).send(:enable_for_program_ids, org.program_ids)
    assert_equal [languages(:hindi)], Language.supported_for(false, non_admin_member, albers)

    organization_languages(:hindi).send(:disable_for_program_ids, [albers.id, nwen.id])
    assert_equal [], Language.supported_for(false, non_admin_member, albers)

    assert_equal [languages(:hindi)], Language.supported_for(false, non_admin_member, org)

    assert_equal [], Language.supported_for(false, non_admin_member, nwen)

    languages(:telugu).update_attributes!(enabled: true)
    organization_languages(:telugu).update_attributes!(enabled: OrganizationLanguage::EnabledFor::ALL)
    organization_languages(:telugu).send(:enable_for_program_ids, org.program_ids)
    assert_equal [languages(:telugu)], Language.supported_for(false, non_admin_member, nwen)

    assert_equal [languages(:hindi), languages(:telugu)], Language.supported_for(false, non_admin_member, org)

    assert_equal [languages(:hindi), languages(:telugu)], Language.supported_for(false, non_admin_member, nil, from_non_org: true)
  end

  def test_get_title_in_organization
    language = languages(:hindi)
    organization_languages(:hindi).update_column(:title, "Abcd")
    Language.any_instance.expects(:for_organization).returns(organization_languages(:hindi))
    assert_equal "Abcd", language.get_title_in_organization(programs(:org_primary))
    Language.any_instance.expects(:for_organization).returns(nil)
    assert_equal "Hindi", language.get_title_in_organization(programs(:org_primary))
  end

  def test_for_organization
    language = languages(:hindi)
    organization_languages(:hindi).update_column(:enabled, OrganizationLanguage::EnabledFor::NONE)
    assert_equal organization_languages(:hindi).id, language.for_organization(programs(:org_primary)).id
    assert_nil language.for_organization(programs(:org_foster))
  end

  private

  def check_for_delta_indexing(member, options = {})
    if options[:no_reindex]
      DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, member.users.pluck(:id)).never
      DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(Member, [
        member.id]).never
    else
      DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, member.users.pluck(:id)).once
      DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(Member, [
        member.id]).once
    end
    yield
  end

end
