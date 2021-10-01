module PreviewFormsCommon
  def check_authorization_for_membership_questions(program = @current_program)
    program && is_membership_form_enabled?(program)
  end

  def check_for_membership_form_access
    super_user_or? { program_view? ? current_user.is_admin? : wob_member.admin? }
  end
end