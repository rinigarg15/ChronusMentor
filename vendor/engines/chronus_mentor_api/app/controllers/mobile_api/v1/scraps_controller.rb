class MobileApi::V1::ScrapsController < MobileApi::V1::MentoringAreaController
  include ScrapExtensions
  before_action :fetch_scrap, :only => [:show, :destroy]
  before_action :handle_group_access, :only => [:index, :destroy]
  after_action :mark_visit, :except => [:create]
  after_action :mark_tree_as_read, :only => [:show]
  respond_to :json

  SCRAPS_PER_PAGE = 20

  def new
    @new_scrap = @group.scraps.new
    render_success("scraps/new")
  end

  def index
    scraps_scope = Scrap.of_member_in_group(@current_member.id, @group.id)
    root_scrap_ids = scraps_scope.present? ? scraps_scope.select("DISTINCT root_id").collect(&:root_id) : []
    options = {:start_index => params[:start_index].to_i, :end_index => params[:start_index].to_i + SCRAPS_PER_PAGE - 1 , :is_admin_viewing_scraps => false}
    @scraps_hash = get_scrap_messages_index(root_scrap_ids, @current_member, options)
    @total_scraps_count = root_scrap_ids.size
    render_success("scraps/index")
  end

  def create
    if params[:scrap][:parent_id].present?
      parent_scrap = @current_program.scraps.find(params[:scrap][:parent_id])
      @scrap = parent_scrap.build_reply(@current_member)
    else
      @scrap = @group.scraps.new(:sender => @current_member, :program_id => @group.program_id)
    end
    if @group.present?
      @scrap.attributes = params[:scrap].pick(:subject, :content, :attachment, :reply_within)
      @scrap.create_receivers! unless @scrap.reply?
      if @scrap.save!
        render_presenter_response({data: {id: @scrap.id}, success: true}) and return
      end
    end
    render_errors(@scrap.errors.full_messages)
  end

  def show
    if @scrap.can_be_viewed?(@current_member)
      render_success("scraps/show")
    else
      render_error_response
    end
  end

  def destroy
    if @scrap.can_be_replied_or_deleted?(@current_member)
      @scrap.mark_deleted!(@current_member)
      render_presenter_response({data: {id: @scrap.id}, success: true})
    else
      render_error_response
    end
  end

  private

  def fetch_scrap
    @scrap = @group.scraps.find_by(id: params[:id])
    unless @scrap.present?
      render_errors([ApiConstants::CommonErrors::ENTITY_NOT_FOUND % {entity: Scrap.name, attribute: :id, value: params[:id]}], 404) and return
    end
  end

  def mark_tree_as_read
    @scrap.mark_tree_as_read!(@current_member)
  end

  def handle_group_access
    unless @group.present?
      render_errors([ApiConstants::CommonErrors::ENTITY_NOT_FOUND % {entity: Group.name, attribute: :id, value: params[:id]}], 404) and return
    end
    unless @group.has_member?(current_user) || current_user.is_admin?
      render_errors([ApiConstants::ACCESS_UNAUTHORISED], 404) and return
    end
  end

  def mark_notification_read
    unless @scrap.can_be_viewed?(@current_member)
      render_error_response
    end
  end
end