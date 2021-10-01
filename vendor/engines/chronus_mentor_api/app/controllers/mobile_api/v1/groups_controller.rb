class MobileApi::V1::GroupsController < MobileApi::V1::MentoringAreaController
  include ScrapExtensions
  skip_before_action :fetch_group
  skip_before_action :set_page_controls_allowed
  after_action :mark_visit, only: :show
  before_action :build_presenter

  MAX_SCRAPS = 3
  
  def show
    @group, result = @presenter.find(params[:id], current_user)
    set_page_controls_allowed
    result[:data].merge!(fetch_scraps_data) if result[:data].present?
    render_presenter_response(result)
  end

protected
  def build_presenter
    @presenter = MobileApi::V1::GroupsPresenter.new(@current_program)
  end

  def fetch_scraps_data
    @group = @current_program.groups.find_by(id: params[:id])
    if @group.present?
      if !@group.has_member?(current_user) && current_user.is_admin?
        is_admin_viewing_scraps = true
        scraps_scope = @group.scraps
      else
        scraps_scope = Scrap.of_member_in_group(@current_member.id, @group.id)
      end
      root_scrap_ids = scraps_scope.select('DISTINCT root_id').collect(&:root_id)
      options = {:start_index => 0, :end_index => MAX_SCRAPS, :is_admin_viewing_scraps => is_admin_viewing_scraps}
      @scraps_hash = get_scrap_messages_index(root_scrap_ids, wob_member, options)
      @total_scraps_count = root_scrap_ids.count
      JSON.parse(render_to_string("mobile_api/v1/scraps/index.json.jbuilder", locals: {defaults: {}}))
    end
  end
end
