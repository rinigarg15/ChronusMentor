module Report::SectionsControllerUtils
  def self.included(controller)
    controller.helper_method :can_manage_report_section?
  end

  def can_manage_report_section?
    super_console?
  end
end