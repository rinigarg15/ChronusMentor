class CareerDev::PortalsController < ProgramsController
  def new
    @program = @current_organization.portals.new(:program_type => CareerDev::Portal::ProgramType::CHRONUS_CAREER)
  end

  def create
    @message_warnings = {}
    @program = @current_organization.portals.new
    assign_program_params(:career_dev_portal)
    is_success = save_program

    if is_success
      set_program_owner
      if @program.created_using_solution_pack?
        unless import_from_solution_pack
          redirect_to new_career_dev_portal_path(root: nil) and return
        end
      else
        flash[:notice] = "career_dev.flash_message.portal_flash.created".translate
      end
      set_current_user_redirect_to_program_root
    else
      handle_program_creation_failure
    end
  end

  private

  def assign_program_params(program_type)
    super
    @program.engagement_type = nil
  end
end