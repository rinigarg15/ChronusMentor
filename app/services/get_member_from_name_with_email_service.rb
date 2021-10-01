class GetMemberFromNameWithEmailService
  def initialize(name_with_email, organization)
    email = Member.extract_email_from_name_with_email(name_with_email)
    @member = organization.members.find_by(email: email)
  end

  def member
    @member
  end

  def get_user(program, role='all')
    program.send("#{role}_users").of_member(@member).first if @member
  end
end