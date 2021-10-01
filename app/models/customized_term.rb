# == Schema Information
#
# Table name: customized_terms
#
#  id                        :integer          not null, primary key
#  ref_obj_id                :integer          not null
#  ref_obj_type              :string(255)      not null
#  term_type                 :string(255)
#  term                      :string(255)      not null
#  term_downcase             :string(255)      not null
#  pluralized_term           :string(255)      not null
#  pluralized_term_downcase  :string(255)      not null
#  articleized_term          :string(255)      not null
#  articleized_term_downcase :string(255)      not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#

class CustomizedTerm < ActiveRecord::Base
  belongs_to :ref_obj, polymorphic: true

  validates :ref_obj, :term, :term_downcase, :pluralized_term, :pluralized_term_downcase, :articleized_term, :articleized_term_downcase, presence: true
  validates :term_type, uniqueness: { scope: [:ref_obj_id, :ref_obj_type] }, presence: true

  translates :term, :term_downcase, :pluralized_term, :pluralized_term_downcase, :articleized_term, :articleized_term_downcase

  module TermType
    ROLE_TERM = 'Role'
    MENTORING_CONNECTION_TERM = 'Mentoring_Connection'
    PROGRAM_TERM = 'Program'
    RESOURCE_TERM = 'Resource'
    ARTICLE_TERM = 'Article'
    MEETING_TERM = 'Meeting'
    ADMIN_TERM = 'Admin'
    MENTORING_TERM = 'Mentoring'
    CAREER_DEVELOPMENT_TERM = 'Career_Development'

    ALL_NON_ROLE_TERMS = [MENTORING_CONNECTION_TERM, MENTORING_TERM, CAREER_DEVELOPMENT_TERM, ARTICLE_TERM, PROGRAM_TERM, RESOURCE_TERM, MEETING_TERM, ADMIN_TERM]
    PROGRAM_LEVEL_TERMS = [ROLE_TERM, MENTORING_CONNECTION_TERM, ARTICLE_TERM, MEETING_TERM, RESOURCE_TERM, MENTORING_TERM]
    ORGANIZATION_LEVEL_TERMS = [PROGRAM_TERM, CAREER_DEVELOPMENT_TERM, ADMIN_TERM]
    CAREER_DEVELOPMENT_TERMS = [CAREER_DEVELOPMENT_TERM]
  end

  def save_term(term, term_type)
    org_term = nil
    if self.ref_obj.is_a?(Program) && TermType::ORGANIZATION_LEVEL_TERMS.include?(term_type)
      org_term = self.ref_obj.organization.term_for(term_type)
    end
    term = org_term || term
    self.term = term.term
    self.term_downcase = term.term_downcase
    self.pluralized_term = term.pluralized_term
    self.pluralized_term_downcase = term.pluralized_term_downcase
    self.articleized_term = term.articleized_term
    self.articleized_term_downcase = term.articleized_term_downcase
    self.term_type = term_type
    self.save
    return self
  end

  def update_term(term_params)
    self.term = term_params[:term]
    self.term_downcase = term_params[:term_downcase] || UnicodeUtils.downcase(self.term)
    self.pluralized_term = term_params[:pluralized_term] || self.term.pluralize
    self.articleized_term = term_params[:articleized_term] || self.term.articleize
    self.pluralized_term_downcase = term_params[:pluralized_term_downcase] || UnicodeUtils.downcase(self.pluralized_term)
    self.articleized_term_downcase = term_params[:articleized_term_downcase] || UnicodeUtils.downcase(self.articleized_term)
    self.save!
  end

  def to_downcase(term)
    UnicodeUtils.downcase(term)
  end
end
