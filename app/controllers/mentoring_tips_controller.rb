class MentoringTipsController < ApplicationController
  before_action :set_bulk_dj_priority
  before_action :fetch_mentoring_tip, :only => [:update, :edit, :destroy]
  before_action :initialize_filter, :only => [:index, :update_all]

  allow :user => :can_manage_mentoring_tips?
  allow :exec => :check_program_has_ongoing_mentoring_enabled

  def create
    role_names = params[:mentoring_tip].delete(:role_names_str)
    @mentoring_tip = @current_program.mentoring_tips.new(mentoring_tip_params(:create))
    @mentoring_tip.role_names = role_names
    @mentoring_tip.save
  end

  def index
    @mentoring_tips = @current_program.mentoring_tips.for_role(@filter_field)
    @new_mentoring_tip = @current_program.mentoring_tips.new
    @new_mentoring_tip.role_names = [@filter_field]
  end

  def edit
  end

  def update
    @mentoring_tip.update_attributes(mentoring_tip_params(:update))
  end

  def update_all
    @current_program.mentoring_tips.for_role(@filter_field).update_all(:enabled => (params[:enable] == "true"))
    redirect_to mentoring_tips_path(:filter => @filter_field)
  end

  def destroy
    @mentoring_tip.destroy
  end

  private

  def mentoring_tip_params(action)
    params.require(:mentoring_tip).permit(MentoringTip::MASS_UPDATE_ATTRIBUTES[action])
  end

  def fetch_mentoring_tip
    @mentoring_tip = @current_program.mentoring_tips.find(params[:id])
  end

  def initialize_filter
    @filter_field = @current_program.roles.for_mentoring.collect(&:name).include?(params[:filter]) ? params[:filter] : RoleConstants::MENTOR_NAME
  end

end
