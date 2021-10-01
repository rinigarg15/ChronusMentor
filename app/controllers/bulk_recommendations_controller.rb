class BulkRecommendationsController < ApplicationController
  include BulkMatchUtils

  skip_before_action :back_mark_pages, except: [:bulk_recommendation]
  before_action :set_bulk_dj_priority
  before_action :set_orientation_type, only: [:bulk_recommendation, :refresh_results, :update_settings, :alter_pickable_slots]
  allow user: :can_manage_connections?
  allow exec: :check_program_has_ongoing_mentoring_enabled
  allow exec: :mentor_recommendation_enabled?
  before_action :fetch_bulk_recommendation

  
  def bulk_recommendation
    if request.xhr?
      @bulk_match = BulkRecommendation.find_or_initialize_by(program_id: @current_program.id)
      @bulk_match.update_bulk_entry(params["mentor_view_id"], params["mentee_view_id"])
      compute_bulk_match_results(@current_program, @bulk_match)
    else
      @set_source_info = params.permit(:controller, :action, :id)
      @bulk_match = BulkRecommendation.find_or_initialize_by(program_id: @current_program.id)
      @recommend_mentors = true
      set_admin_view_details
    end
  end

  def refresh_results
    compute_bulk_match_results(@current_program, @bulk_match)
    render template: "bulk_matches/bulk_match", formats: [:js]
  end

  def fetch_settings
    render partial: "bulk_matches/popup_bulk_match_settings", locals: {orientation_type: BulkMatch::OrientationType::MENTEE_TO_MENTOR}, layout: false
  end

  def update_settings
    if params[:sort].present?
      @bulk_match.update_attributes!(sort_value: params[:sort_value], sort_order: params[:sort_order])
    else
      @refresh_results = (@bulk_match.max_pickable_slots.to_i > params[:bulk_recommendation][:max_pickable_slots].to_i)
      @refresh_results ||= (@bulk_match.max_suggestion_count != params[:bulk_recommendation][:max_suggestion_count].to_i)
      @bulk_match.update_attributes!(update_settings_bulk_recommendation_params)
      compute_bulk_match_results(@current_program, @bulk_match) if @refresh_results
    end
    render template: "bulk_matches/update_settings"
  end

  def alter_pickable_slots
    @mentor = @current_program.mentor_users.find(params[:mentor_id].to_i)
    @student = @current_program.student_users.find(params[:student_id].to_i)
    render partial: "bulk_matches/alter_pickable_slots_popup", layout: false
  end

  def update_bulk_recommendation_pair
    ActiveRecord::Base.transaction do
      if params[:update_type] == AbstractBulkMatch::UpdateType::DISCARD
        @current_program.mentor_recommendations.find_by(receiver_id: params[:student_id]).destroy
      elsif params[:update_type] == AbstractBulkMatch::UpdateType::DRAFT
        draft_mentor_recommendation(params[:student_id], params[:mentor_id_list].split(","))
      elsif params[:update_type] == AbstractBulkMatch::UpdateType::PUBLISH
        draft_mentor_recommendation(params[:student_id], params[:mentor_id_list].split(",")).publish!
      end
    end
    head :ok
  end

  def bulk_update_bulk_recommendation_pair
    student_ids = params[:student_mentor_map].keys.map(&:to_i)

    ActiveRecord::Base.transaction do
      case params[:update_type]
      when AbstractBulkMatch::UpdateType::DISCARD
        @current_program.mentor_recommendations.where(receiver_id: student_ids).destroy_all
      when AbstractBulkMatch::UpdateType::DRAFT
        params[:student_mentor_map].each_pair do |student_id, mentor_ids|
          draft_mentor_recommendation(student_id, mentor_ids)
        end
      when AbstractBulkMatch::UpdateType::PUBLISH
        params[:student_mentor_map].each_pair do |student_id, mentor_ids|
          draft_mentor_recommendation(student_id, mentor_ids)
        end
        @current_program.mentor_recommendations.where(receiver_id: student_ids).update_all(status: MentorRecommendation::Status::PUBLISHED, published_at: Time.now)
        MentorRecommendation.delay.send_bulk_publish_mails(@current_program.id, student_ids)
      end
    end
    head :ok
  end

  private

  def set_admin_view_details
    fetch_admin_views_for_matching
    fetch_mentee_and_mentor_views(@bulk_match.mentee_view, @bulk_match.mentor_view, params[:admin_view_id])
  end

  def update_settings_bulk_recommendation_params
    params[:bulk_recommendation].present? ? params[:bulk_recommendation].permit(BulkRecommendation::MASS_UPDATE_ATTRIBUTES[:update_settings]) : {}
  end

  def mentor_recommendation_enabled?
    @current_program.mentor_recommendation_enabled?
  end

  def set_orientation_type
    @orientation_type = BulkMatch::OrientationType::MENTEE_TO_MENTOR
  end

  def fetch_bulk_recommendation
    @recommend_mentors = true
    @bulk_match = @current_program.bulk_recommendation
  end

  def draft_mentor_recommendation(receiver_id, recommended_ids)
    mentor_recommendation = @current_program.mentor_recommendations.find_by(receiver_id: receiver_id)
    return mentor_recommendation if mentor_recommendation.present? && mentor_recommendation.is_drafted_mentor_recommendation_for?(recommended_ids)

    mentor_recommendation.try(:destroy)
    mentor_recommendation = @current_program.mentor_recommendations.new(receiver_id: receiver_id, sender_id: current_user.id, status: MentorRecommendation::Status::DRAFTED)
    recommended_ids.each_with_index do |recommended_mentor_id, index|
      mentor_recommendation.recommendation_preferences.new(user_id: recommended_mentor_id, position: index + 1)
    end
    mentor_recommendation.save!
    return mentor_recommendation
  end
end