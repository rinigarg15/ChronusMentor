class MentorRequest::InstructionsController < ApplicationController
  allow :user => :can_manage_mentor_requests?
  allow :exec => :check_program_has_ongoing_mentoring_enabled

  # Only super user can access these pages
  before_action :require_super_user

  def index
    @mentor_request_instruction = @current_program.mentor_request_instruction || MentorRequest::Instruction.new
  end

  def create
    mentor_request_instruction = @current_program.build_mentor_request_instruction(mentor_request_instruction_params(:create))
    assign_user_and_sanitization_version(mentor_request_instruction)
    mentor_request_instruction.save!
    handle_redirect
  end

  def update
    mentor_request_instruction = @current_program.mentor_request_instruction
    assign_user_and_sanitization_version(mentor_request_instruction)
    mentor_request_instruction.update_attributes!(mentor_request_instruction_params(:update))
    handle_redirect
  end

  private
  def mentor_request_instruction_params(action)
    params.require(:mentor_request_instruction).permit(MentorRequest::Instruction::MASS_UPDATE_ATTRIBUTES[action])
  end

  def handle_redirect
    flash[:notice] = "flash_message.instructions_flash.success_v1".translate
    redirect_to mentor_request_instructions_path
  end

end
