class EmailMonitorMail < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'x10n7iqz', # rand(36**8).to_s(36)
    :title        => Proc.new{|program| "Email Monitor"},
    :description  => Proc.new{"Email used for Monitoring purpose"},
    :subject      => Proc.new{"Email Monitoring"},
    :donot_list   => true,
    :level        => EmailCustomization::Level::PROGRAM
  }

  def email_monitor_mail(user = nil, email, program_id)
    @email = email
    @program_id = program_id
    init_mail
    render_mail
  end

  
  private

  def init_mail
    program = Program.find(@program_id)
    set_program(program)
    setup_email(nil, {:email => @email})
    super
  end

  self.register!
end
