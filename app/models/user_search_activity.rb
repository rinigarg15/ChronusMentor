# == Schema Information
#
# Table name: user_search_activities
#
#  id                     :integer          not null, primary key
#  program_id             :integer          not null
#  user_id                :integer          not null
#  profile_question_id    :integer
#  question_choice_id     :integer
#  locale                 :string
#  profile_question_text  :text(65535)
#  search_text            :text(65535)
#  source                 :integer
#  session_id             :string 
#  created_at             :datetime
#  updated_at             :datetime
#

class UserSearchActivity < ActiveRecord::Base
  
  include UserSearchActivityElasticsearchSettings
  include UserSearchActivityElasticsearchQueries
  # Relationships  
  belongs_to_program
  belongs_to :user
  belongs_to :profile_question
  belongs_to :question_choice

  # Validations
  validates :program_id, :user_id, presence: true

  module Src
    GLOBAL_SEARCH = 0
    LISTING_PAGE = 1
  end

  def self.add_user_activity(user, options = {})
    add_filter_activity(user, options)
    add_search_activity(user, options)
  end

  def self.add_search_activity(user, options)
    search_text = options[:quick_search]
    return unless search_text.present?
    create_user_search_activity(user, {search_text: search_text, locale: options[:locale], source: options[:source], session_id: options[:session_id]})
  end

  def self.add_filter_activity(user, options = {})
    add_custom_profile_filters_activity(user, options)
    add_location_filter_activity(user, options)
  end

  def self.add_location_filter_activity(user, options)
    location_params = options[:location]
    if location_params.present?
      profile_question_id = location_params.keys.first
      profile_question = ProfileQuestion.find_by(id: profile_question_id)
      return if profile_question.nil?
      location_text = location_params["#{profile_question_id}"]["name"].split(",")[0]
      create_user_search_activity(user, {profile_question_id: profile_question_id, profile_question_text: profile_question.question_text, search_text: location_text, locale: options[:locale], source: options[:source], session_id: options[:session_id]})
    end
  end

  def self.add_custom_profile_filters_activity(user, options)
    custom_profile_filters = options[:custom_profile_filters]
    return unless custom_profile_filters.present?
    custom_profile_filters.each do |profile_question_id, question_choice_ids_or_text|
      profile_question = ProfileQuestion.find_by(id: profile_question_id)
      next if profile_question.nil?
      options = {profile_question_id: profile_question_id, profile_question_text: profile_question.question_text, locale: options[:locale], source: options[:source], session_id: options[:session_id]}
      if profile_question.with_question_choices?
        add_filter_activity_for_choice_based_question(user, question_choice_ids_or_text, options)
      else
        add_filter_activity_for_text_based_question(user, question_choice_ids_or_text, options)
      end
    end
  end

  def self.add_filter_activity_for_choice_based_question(user, question_choice_ids, options)
    question_choice_ids.each do |question_choice_id|
      question_choice = QuestionChoice.find_by(id: question_choice_id)
      next if question_choice.nil?
      activity_options = options.merge!({question_choice_id: question_choice_id, search_text: question_choice.text, session_id: options[:session_id]})
      create_user_search_activity(user, activity_options)
    end
  end

  def self.add_filter_activity_for_text_based_question(user, search_text, options)
    activity_options = options.merge!({search_text: search_text})
    create_user_search_activity(user, activity_options)
  end

  def self.create_user_search_activity(user, options)
    program = user.program
    search_activity = UserSearchActivity.find_or_initialize_by({user: user, program: program}.merge!(options))
    search_activity.save! if search_activity.new_record?
  end

end
