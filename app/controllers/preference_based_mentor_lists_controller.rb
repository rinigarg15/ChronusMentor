class PreferenceBasedMentorListsController < ApplicationController

  allow user: :can_view_preferece_based_mentor_lists?
  before_action :set_attributes_for_ignore, only: [:ignore]

  def index
    @pbml_recommendations_service = PreferenceBasedMentorListsRecommendationService.new(current_user)
  end

  def ignore
    pbml = current_user.preference_based_mentor_lists.find_or_initialize_by(ref_obj: @ref_obj, profile_question: @profile_question)
    pbml.weight = @weight
    pbml.ignored = true
    pbml.save!
    head :ok
  end

  private

  def set_attributes_for_ignore
    klass = get_ref_obj_klass
    @ref_obj = klass.find(params[:preference_based_mentor_list][:ref_obj_id])
    @profile_question = @current_organization.profile_questions.find(params[:preference_based_mentor_list][:profile_question_id])
    @weight = params[:preference_based_mentor_list][:weight].to_f
  end

  def get_ref_obj_klass
    params[:preference_based_mentor_list][:ref_obj_type].constantize_only(PreferenceBasedMentorList::Type.all)
  end
end
