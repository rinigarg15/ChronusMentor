module AdminViewsPreviewUtils

  def set_preview_view_details(options={})
    @set_source_info = params.delete(:source_info).try(:permit, [:controller, :action, :id, :section])
    @role = params[:role]
    @admin_view = @current_program.admin_views.find(params[:admin_view_id])
    @admin_view_filters, @admin_view_users = @admin_view.get_filters_and_users(options)
  end
end