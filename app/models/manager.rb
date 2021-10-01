# == Schema Information
#
# Table name: managers
#
#  id                :integer          not null, primary key
#  first_name        :string(255)
#  last_name         :string(255)
#  email             :string(255)
#  profile_answer_id :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  member_id         :integer
#

class Manager < ActiveRecord::Base
  has_paper_trail on: [:update], class_name: 'ChronusVersion'
  belongs_to :profile_answer, :inverse_of => :manager
  belongs_to :member, :inverse_of => :manager_entries

  has_one :managee, :through => :profile_answer, :source => :ref_obj, :source_type => "Member"

  attr_accessor :program

  validates :first_name, :last_name, :email, :profile_answer, :presence => true
  validates :email, :email_format => {:generate_message => true}
  scope :with_managee, -> { where(:profile_answers => {:ref_obj_type => "Member"}).joins(:profile_answer)}

  scope :in_organization, ->(organization_id) {
    joins({:profile_answer => :profile_question}).where({ :profile_questions => {:organization_id => organization_id}})
  }

  def full_data
    [self.full_name, self.email].join(ProfileAnswer::SEPERATOR)
  end

  def full_name
    "#{self.first_name} #{self.last_name}".strip
  end

  def self.column_names_for_question(question)
    question.manager? ? export_column_names.map { |_, name| "#{question.question_text}-#{name}" } : []
  end

  def self.export_column_names
    {
      first_name: Manager.human_attribute_name(:first_name),
      last_name: Manager.human_attribute_name(:last_name),
      email: Manager.human_attribute_name(:email)
    }
  end

  def update_member_id(options={})
    if options[:manager_member_id].nil?
      org_id = options[:organization_id] || self.profile_answer.profile_question.organization_id
      m_id = Member.of_organization(org_id).find_by(email:self.email).try(:id)
    else
      m_id = options[:manager_member_id]
    end
    self.member_id = m_id
  end

end
