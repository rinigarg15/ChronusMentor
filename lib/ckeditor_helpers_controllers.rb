module CkeditorHelpersControllers

  protected

  def ckeditor_filebrowser_scope(options = {})
    super( { program_id: @current_organization.id }.merge(options))
  end
end