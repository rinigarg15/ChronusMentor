require_relative "./../test_helper.rb"

class LoginIdentifierTest < ActiveSupport::TestCase

  def test_presence_validations
    login_identifier = LoginIdentifier.new
    assert_false login_identifier.valid?
    assert_equal ["can't be blank"], login_identifier.errors[:member]
    assert_equal ["can't be blank"], login_identifier.errors[:auth_config_id]
  end

  def test_auth_config_id_uniqueness_validations
    member = members(:f_mentor)

    e = assert_raise ActiveRecord::RecordInvalid do
      LoginIdentifier.create!(member: member, auth_config: member.organization.chronus_auth)
    end
    assert_equal "Validation failed: Auth config has already been taken", e.message
  end

  def test_identifier_uniqueness_validations
    non_indigenous_auth = programs(:org_primary).linkedin_oauth

    LoginIdentifier.create!(member: members(:f_mentor), auth_config: non_indigenous_auth, identifier: "uid")
    e = assert_raise ActiveRecord::RecordInvalid do
      LoginIdentifier.create!(member: members(:f_student), auth_config: non_indigenous_auth, identifier: "UID")
    end
    assert_equal "Validation failed: Identifier has already been taken", e.message
  end

  def test_should_be_valid_when_auth_config_disabled
    login_identifier = LoginIdentifier.first
    login_identifier.auth_config.disable!
    assert login_identifier.reload.valid?
  end
end