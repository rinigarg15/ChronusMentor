require_relative './../../test_helper.rb'

class MemberMergerTest < ActiveSupport::TestCase

  def test_integrity
    # When merging members, the (member_associations - MemberMerger::WhitelistedAssociations.all)
    # are ignored.
    member_associations = Member.get_assoc_name_foreign_key_map.keys
    assert_equal_unordered [
      :versions,
      :passwords,
      :active_users,
      :location_answer,
      :job_logs,
      :loggable_job_logs,
      :shown_recent_activities,
      :o_auth_credentials,
      :google_o_auth_credentials,
      :microsoft_o_auth_credentials,
      :outlook_o_auth_credentials,
      :office365_o_auth_credentials
    ], (member_associations - MemberMerger::WhitelistedAssociations.all)
  end

  def test_can_be_merged
    assert_false MemberMerger.new(nil, nil, nil).send(:can_be_merged?)
    assert_false MemberMerger.new(members(:f_mentor), members(:f_student), nil).send(:can_be_merged?)
    assert_false MemberMerger.new(members(:f_student), members(:moderated_student), members(:moderated_admin)).send(:can_be_merged?)
    assert MemberMerger.new(members(:f_student), members(:moderated_student), members(:f_admin)).send(:can_be_merged?)
  end

  def test_merge
    member_to_discard = members(:f_student)
    member_to_retain = members(:moderated_student)
    admin_member = members(:f_admin)
    member_merger = MemberMerger.new(member_to_discard, member_to_retain, admin_member)

    # to verify has_one association
    create_profile_picture(member_to_discard)
    profile_picture = member_to_discard.profile_picture
    # to verify update of admin_id in membership_requests
    user_of_member_to_discard = member_merger.users_of_member_to_discard.first
    program = user_of_member_to_discard.program
    program.membership_requests.update_all(status: MembershipRequest::Status::REJECTED, response_text: "Reason", admin_id: user_of_member_to_discard.id)

    non_unique_associations = MemberMerger::WhitelistedAssociations.all - MemberMerger::WhitelistedAssociations.uniqueness_scope_map.keys
    assert_differences get_assoc_differences(non_unique_associations) do
      assert_difference "Member.count", -1 do
        assert member_merger.merge
      end
    end
    assert_raise ActiveRecord::RecordNotFound do
      member_to_discard.reload
    end
    assert_equal [users(:f_admin).id], program.membership_requests.pluck(:admin_id).uniq
    assert_equal member_to_retain.id, profile_picture.reload.member_id
  end

  def test_merge_handle_uniqueness_scope
    member_to_discard = members(:f_student)
    member_to_retain = members(:moderated_student)
    member_merger = MemberMerger.new(member_to_discard, member_to_retain, members(:f_admin))

    create_profile_picture(member_to_discard)
    create_profile_picture(member_to_retain)
    profile_picture = member_to_discard.profile_picture
    create_uniqueness_scope_objects(member_to_discard, member_to_retain)

    assert_differences get_assoc_differences(MemberMerger::WhitelistedAssociations.uniqueness_scope_map.keys, -1) do
      assert_difference "Member.count", -1 do
        member_merger.merge
      end
    end
    assert_raise ActiveRecord::RecordNotFound do
      profile_picture.reload
    end
  end

  private

  def get_assoc_differences(assoc_to_consider, count = 0)
    assoc_differences = []
    Member.reflect_on_all_associations.each do |assoc|
      next if assoc_to_consider.exclude?(assoc.name)
      assoc_differences << ["#{assoc.klass.name}.count", count]
    end
    assoc_differences
  end

  def create_uniqueness_scope_objects(member_to_discard, member_to_retain)
    MemberMerger::WhitelistedAssociations.uniqueness_scope_map.keys.each do |assoc|
      case assoc
      when :profile_answers
        profile_question = profile_questions(:string_q)
        member_to_discard.profile_answers.create!(profile_question_id: profile_question.id, answer_text: "Sun")
        member_to_retain.profile_answers.create!(profile_question_id: profile_question.id, answer_text: "Moon")
      when :one_time_flags
        member_to_discard.one_time_flags.create!(message_tag: OneTimeFlag::Flags::TourTags::CAMPAIGN_TOUR_TAG)
        member_to_retain.one_time_flags.create!(message_tag: OneTimeFlag::Flags::TourTags::CAMPAIGN_TOUR_TAG)
      when :login_identifiers
        # do nothing
      else
        # If fails here, please add one more 'when' clause and handle it!
        assert_equal 1, 0
      end
    end
  end
end