require_relative '../test_helper'

class MemberLanguageTest < ActiveSupport::TestCase
  def test_validates_member
    member_language = MemberLanguage.new
    assert_false member_language.valid?
    assert_equal(["can't be blank"], member_language.errors[:member])
    assert_equal(["can't be blank"], member_language.errors[:language])
    member_language = MemberLanguage.create!(member: members(:f_mentor), language: languages(:hindi))
    assert member_language.valid?
  end

  def test_belongs_to
    member = members(:f_mentor)
    language = languages(:hindi)
    member_language = MemberLanguage.create!(member: member, language: language)
    assert_equal member_language.member, member
    assert_equal member_language.language, language
  end

  def test_observers_reindex_es
    member = members(:f_mentor)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(Member, [member.id]).times(3)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, member.user_ids).times(3)
    member_language = MemberLanguage.create!(member: member, language: languages(:hindi))
    member_language.update_attribute(:language_id, languages(:telugu).id)
    member_language.destroy
  end
end