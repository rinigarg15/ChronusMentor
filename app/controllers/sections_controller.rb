class SectionsController < ApplicationController  

  skip_before_action :require_program, :login_required_in_program
  before_action :login_required_in_organization
  
  before_action :fetch_section, :only => [:edit, :update, :destroy]

  after_action :expire_cached_program_user_filters, :only => [:create, :update, :destroy]

  allow :exec => :check_admin_access
  
  def new
    @section = @current_organization.sections.new
  end

  def create
    @section = @current_organization.sections.new(section_params(:create))
    position = @current_organization.sections.maximum(:position)
    @section.update_attributes(:position => position + 1, :default_field => false)
  end

  def edit
    render :new
  end

  def update
    if params[:new_order] && update_order
      head :ok
    else
      @section.update_attributes(section_params(:update))
    end
  end

  def destroy
    allow! :exec => Proc.new { !@section.default_field? }
    @section.destroy
  end

  private

  def section_params(action)
    params.require(:section).permit(Section::MASS_UPDATE_ATTRIBUTES[action])
  end

  # Returns whether the current member is an organization admin.
  def check_admin_access
    wob_member && wob_member.admin?
  end
  
  def fetch_section
    @section = @current_organization.sections.find_by(id: params[:id])
  end

  def update_order
    ques = @current_organization.sections.find(params[:new_order])
    params[:new_order].map{|id| ques.detect{|s| s.id == id.to_i}}.each_with_index do |section, index|
      section.update_attribute(:position, index + 2)
    end
  end

end