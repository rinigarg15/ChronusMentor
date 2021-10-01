# == Schema Information
#
# Table name: flags
#
#  id           :integer          not null, primary key
#  content_type :string(255)
#  content_id   :integer
#  reason       :text(16777215)
#  user_id      :integer
#  resolver_id  :integer
#  resolved_at  :datetime
#  status       :integer
#  program_id   :integer
#  created_at   :datetime
#  updated_at   :datetime
#

class Flag < ActiveRecord::Base

  module Status
    UNRESOLVED = 0
    DELETED = 1
    EDITED = 2
    ALLOWED = 3

    def self.all
      constants.collect{|c| const_get(c)}
    end
  end

  module Tabs
    UNRESOLVED = 0
    RESOLVED = 1
  end

  belongs_to :user
  belongs_to :content, polymorphic: true
  belongs_to :program
  belongs_to :resolver, foreign_key: "resolver_id", class_name: "User"

  validates :user_id, :reason, :program_id, presence: true
  validates :status, inclusion: {in: Status.all}

  scope :unresolved, -> { where("flags.status= ?", Status::UNRESOLVED)}
  scope :resolved, -> { where("flags.status != ?", Status::UNRESOLVED)}
  scope :ordered, -> { order('id DESC')}
  scope :in_program, ->(program) { where(['flags.program_id = ?', program.id])}

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:reason, :content_type, :content_id]
  }

  class << self

    def flaggable_klasses
      [Article, QaQuestion, QaAnswer, Post, Comment]
    end

    def flaggable_content_types
      flaggable_klasses.map(&:name)
    end

    def flagged_and_unresolved_by_user?(content, user)
      content.flags.present? && content.flags.in_program(user.program).unresolved.find_by(user_id: user.id).present?
    end

    def flagged_and_unresolved?(content, program)
      content.flags.present? && content.flags.in_program(program).unresolved.size > 0
    end

    def set_status_as_deleted(content, resolver, resolved_at)
      resolver_id = resolver && resolver.is_admin? ? resolver.id : nil
      content.flags.each{|flag| flag.update_attributes({status: Status::DELETED, resolver_id: resolver_id, resolved_at: resolved_at})}
    end

    def set_flags_status_as_edited(content, resolver, resolved_at)
      resolver_id = resolver && resolver.is_admin? ? resolver.id : nil
      content.flags.each{|flag| flag.update_attributes({status: Status::EDITED, resolver_id: resolver_id, resolved_at: resolved_at}) if flag.unresolved? }
    end

    def ignore_all_flags(content, resolver, resolved_at)
      resolver_id = resolver && resolver.is_admin? ? resolver.id : nil
      content.flags.in_program(resolver.program).each{|flag| flag.update_attributes({status: Flag::Status::ALLOWED, resolver_id: resolver_id, resolved_at: resolved_at}) if flag.unresolved? }
    end

    def count_for_content(content, program)
      content.flags.in_program(program).size
    end

    def content_owner(content, program)
      case content.class.to_s
      when 'Article'
        return content.author.user_in_program(program)
      else
        return content.user
      end
    end

    def content_owner_is_user?(content, user)
      user == Flag.content_owner(content, user.program)
    end

    # This should return AREL only
    def get_flags(scope, options = {})
      filter = options[:filter]
      disabled_features = []
      disabled_features += [Post.name] unless scope.forums_enabled?
      disabled_features += [Article.name, Comment.name] unless scope.articles_enabled?
      disabled_features += [QaQuestion.name, QaAnswer.name] unless scope.qa_enabled?
      arel_chain = scope.flags
      arel_chain = arel_chain.where("content_type NOT IN (?)", disabled_features) if disabled_features.any?
      arel_chain = arel_chain.resolved if filter.try(:[], :resolved)
      arel_chain = arel_chain.unresolved if filter.try(:[], :unresolved)
      arel_chain
    end

    def send_content_flagged_admin_notification(flag_id, job_uuid)
      flag = Flag.find_by(id: flag_id)
      return if flag.nil?

      JobLog.compute_with_uuid(flag.program.admin_users, job_uuid, "Content flagged notification to admins") do |admin_user|
        ChronusMailer.content_flagged_admin_notification(admin_user, flag, { :force_send => true, sender: flag.user }).deliver_now
      end
    end
  end

  def unresolved?
    self.status == Status::UNRESOLVED
  end

  def content_type_name
    if self.content_type == Article.name
      self.program.term_for(CustomizedTerm::TermType::ARTICLE_TERM).term
    else
      "feature.flag.content.content_type.#{self.content_type}".translate
    end
  end

end
