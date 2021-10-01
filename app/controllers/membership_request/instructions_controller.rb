class MembershipRequest::InstructionsController < ApplicationController
  # Only super user can access these pages
  before_action :check_authorization_for_membership_questions

  allow :user => :can_manage_membership_forms?

  def create
    @membership_request_instruction = @current_program.build_membership_instruction(membership_request_instruction_params(:create))
    @membership_request_instruction.save!
    render template: "membership_request/instructions/update"
  end

  def update
    @membership_request_instruction = @current_program.abstract_instructions.find(params[:id])
    @membership_request_instruction.update_attributes(membership_request_instruction_params(:update))
  end

  def get_instruction_form
    @membership_request_instruction = @current_program.membership_instruction.presence || @current_program.build_membership_instruction
    render partial: 'membership_request/instructions/show', locals: {instruction: @membership_request_instruction}
  end

  private
  def membership_request_instruction_params(action)
    params.require(:membership_request_instruction).permit(MembershipRequest::Instruction::MASS_UPDATE_ATTRIBUTES[action])
  end

  def check_authorization_for_membership_questions
    allow! :exec => lambda {is_membership_form_enabled?(@current_program)}
  end
end
