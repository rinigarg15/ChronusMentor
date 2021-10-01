class ThreeSixty::ReviewerGroupsController < ThreeSixty::CommonController

  allow :exec => "wob_member.admin?", :only => [:create, :destroy, :edit, :update]
  before_action :fetch_reviewer_group, :only => [:destroy, :edit, :update]

  def index
    @reviewer_groups = @current_organization.three_sixty_reviewer_groups.excluding_self_type
    @active_tab = Tab::SETTINGS
    @show_actions = wob_member.admin?
  end

  def create
    params[:three_sixty_reviewer_group][:threshold] = 0 unless params[:three_sixty_reviewer_group][:threshold].present?
    @reviewer_group = @current_organization.three_sixty_reviewer_groups.create(three_sixty_reviewer_group_params(:create))
  end

  def destroy
    @reviewer_group.destroy
  end

  def edit
  end

  def update
    params[:three_sixty_reviewer_group][:threshold] = 0 unless params[:three_sixty_reviewer_group][:threshold].present?
    @reviewer_group.update_attributes(three_sixty_reviewer_group_params(:update))
  end

  private

  def three_sixty_reviewer_group_params(action)
    params.require(:three_sixty_reviewer_group).permit(ThreeSixty::ReviewerGroup::MASS_UPDATE_ATTRIBUTES[action])
  end

  def fetch_reviewer_group
    @reviewer_group = @current_organization.three_sixty_reviewer_groups.find(params[:id])
  end
end