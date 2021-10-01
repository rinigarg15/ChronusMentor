class ThreeSixty::CompetenciesController < ThreeSixty::CommonController

  allow :exec => "wob_member.admin?", :only => [:new, :create, :edit, :update, :destroy]
  before_action :fetch_competency, :only => [:edit, :update, :destroy]

  def index
    @competencies = @current_organization.three_sixty_competencies.includes(:questions)
    @open_ended_questions = @current_organization.three_sixty_oeqs
    @active_tab = Tab::COMPETENCIES
    @show_actions = wob_member.admin?
  end

  def new
    @competency = @current_organization.three_sixty_competencies.new
    render :partial => "three_sixty/competencies/new", :locals => { :for_new => true }
  end

  def create
    @competency = @current_organization.three_sixty_competencies.create(three_sixty_competency_params(:create))
  end

  def edit
    render :partial => "three_sixty/competencies/new", :locals => { :for_new => false }
  end

  def update
    @competency.update_attributes(three_sixty_competency_params(:update))
  end

  def destroy
    @competency.destroy
  end

  private

  def three_sixty_competency_params(action)
    params.require(:three_sixty_competency).permit(ThreeSixty::Competency::MASS_UPDATE_ATTRIBUTES[action])
  end

  def fetch_competency
    @competency = @current_organization.three_sixty_competencies.find(params[:id])
  end
end