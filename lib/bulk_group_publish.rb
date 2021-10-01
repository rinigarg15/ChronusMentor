class BulkGroupPublish
  attr_accessor :group_ids, :progress, :options, :output_hash

  def initialize(groups, options = {})
    @group_ids = groups.collect(&:id)
    @options = options
    @progress = ProgressStatus.create!(maximum: @group_ids.count, ref_obj: options[:current_user], for: ProgressStatus::For::Group::BULK_PUBLISH, completed_count: 0)
    @output_hash = { error_flash: [], error_group_ids: [], group_ids_with_active_project_requests: [] }
    @options[:program_root] = groups.first.program.root
  end

  def publish_groups_background
    Group.where(id: @group_ids).includes(:active_project_requests).each do |group|
      @output_hash[:group_ids_with_active_project_requests] << group.id if group.active_project_requests.present?
      begin
        group.publish(@options[:current_user], @options[:message], @options[:allow_join])
      rescue ActiveRecord::RecordInvalid
        @output_hash[:error_flash] << group.errors.full_messages.to_sentence
        @output_hash[:error_group_ids] << group.id
      ensure
        @progress.increment!(:completed_count)
      end
    end
    set_errors_and_redirect_path
    store_output
  end

  private

  def store_output
    @progress.update_attributes!(details: @output_hash.except(:group_ids_with_active_project_requests))
  end

  def set_errors_and_redirect_path
    @output_hash[:redirect_path] = @options[:redirect_path]
    handle_active_project_requests if @output_hash[:group_ids_with_active_project_requests].present?
    @output_hash[:error_flash] = @output_hash[:error_flash].uniq
  end

  def handle_active_project_requests
    project_request_params = { filtered_group_ids: @output_hash[:group_ids_with_active_project_requests], from_bulk_publish: true, ga_src: EngagementIndex::Src::GROUP_LISTING, track_publish_ga: true, src: EngagementIndex::Src::PUBLISH_CIRCLE_WIDGET, root: @options[:program_root] }
    if (@output_hash[:group_ids_with_active_project_requests] - @output_hash[:error_group_ids]).present?
      @output_hash[:error_flash] << "feature.connection.content.notice.published_groups_with_pending_requests_html".translate(mentoring_connections: @options[:mentoring_connections_term], project_listing_url: Rails.application.routes.url_helpers.manage_project_requests_path(project_request_params.merge(dont_show_flash: true)))
    end
    @output_hash[:redirect_path] ||=  Rails.application.routes.url_helpers.manage_project_requests_path(project_request_params) if @output_hash[:error_flash].size == 1
  end
end