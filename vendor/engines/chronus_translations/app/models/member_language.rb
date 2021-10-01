class MemberLanguage < ActiveRecord::Base
  belongs_to :member
  belongs_to :language

  validates :member,    :presence => true
  validates :language,  :presence => true

  after_save :reindex_es
  after_destroy :reindex_es

  def reindex_es
    self.class.es_reindex(self)
  end

  def organization_language
    OrganizationLanguage.unscoped.find_by(organization_id: self.member.organization_id, language_id: self.language_id)
  end

  def self.es_reindex(member_language)
    member_ids = Array(member_language).map(&:member_id).uniq
    user_ids = User.where(member_id: member_ids).pluck(:id).uniq
    DelayedEsDocument.delayed_bulk_update_es_documents(Member, member_ids)
    DelayedEsDocument.delayed_bulk_update_es_documents(User, user_ids)
  end
end
