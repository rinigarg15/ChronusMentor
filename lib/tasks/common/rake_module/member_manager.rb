module Common::RakeModule::MemberManager

  def self.get_eager_loadables_for_destroying_dormant_members
    member_eager_loadables = Member.get_eager_loadables_for_destroy
    profile_answer_eager_loadables = ProfileAnswer.get_eager_loadables_for_destroy

    return (member_eager_loadables - [:profile_answers] + [ { profile_answers: profile_answer_eager_loadables } ])
  end
end