# If you dont want a mail to be sent to the deleted user, make user as the first argument.
# If you want mail to be sent always irrespective of the user's state,
# include a last extra hash parameter which has {:force_send => true}. However, there is no need
#   for this parameter in UserMailer. This parameter is stripped off
class DummyMailer
  def self.deliver_now
    return false
  end

end
class ChronusMailer
  # Emails that must be delivered right away irrespective of user's delivery
  # settings.
  EssentialMailers = [
    "user_activation_notification",
    "user_suspension_notification",
    "admin_added_directly_notification",
    "mentor_added_notification",
    "user_with_set_of_roles_added_notification",
    "portal_member_with_set_of_roles_added_notification",
    "portal_member_with_set_of_roles_added_notification_to_review_profile",
    "email_change_notification",
    "forgot_password",
    "group_inactivity_notification",
    "group_inactivity_notification_with_auto_terminate",
    "content_flagged_admin_notification",
    "resend_signup_instructions",
    "admin_view_export",
    "meeting_request_created_notification",
    "meeting_request_reminder_notification"
  ]

  def self.method_missing(method_symbol, *parameters)
    receiver = parameters[0] # Take the first argument(i.e. the receiver)
    mail_locale = I18n.default_locale

    # FIXME: Shouldn't this be *parameters?
    force_send = handle_force_send(parameters)
    mailer = get_mailer(method_symbol)

    return DummyMailer if email_template_disabled?(receiver, mailer)

    should_send_email = false
    disabled_at_user_level = false

    if receiver.instance_of?(User)
      disabled_at_user_level = receiver.is_notification_disabled_for?(mailer.mailer_attributes[:notification_setting]) if mailer.mailer_attributes[:notification_setting]
      allowed_states = mailer.mailer_attributes[:user_states] || []
      if allowed_states.include?(receiver.state)
        if receiver.deleted? # No email to deleted users unless force_send
          should_send_email = force_send
        else # All checks clear. Can send the email now.
          should_send_email = true
        end
      end
      mail_locale = Language.for_member(receiver.member, receiver.program)
    elsif receiver.instance_of?(Member)
      should_send_email = true
      mail_locale = Language.for_member(receiver)
    else # Not a user/member object. Send the mail.
      should_send_email = true
      mail_locale = ChronusMailer.expected_locale_for(receiver)
    end
    # Respect force_send if passed unless disabled at user level.
    should_send_email ||= force_send
    if !disabled_at_user_level && should_send_email
      mail_message = mailer.send(method_symbol, *parameters)
      mail_locale = mailer.mailer_locale(*parameters) if mailer.respond_to?(:mailer_locale)
      mail_message.instance_variable_set("@mail_locale", mail_locale)
      mail_message
    else
      DummyMailer
    end
  end

  private

  def self.expected_locale_for(obj)
    member = case obj
    when Password, MembershipRequest, Manager
      obj.member
    else
      nil
    end
    if member
      program = fetch_receiver_program(obj)
      program.is_a?(Program) ? Language.for_member(member, program) : Language.for_member(member)
    else
      I18n.default_locale
    end
  end

  def self.run_with_locale(locale)
    begin
      current_locale = I18n.locale
      I18n.locale = locale
      yield
    ensure
      I18n.locale = current_locale
    end
  end

  # Find out whether the it is a force send or not If so, remember it, and delete the
  # force_parameter
  def self.handle_force_send(parameters)
    options = parameters.last.instance_of?(Hash) ? parameters.last : {}
    force_send = false
    if options.any?
      force_send = options.delete(:force_send)

      # If the options were only for ChronusMailer, delete all of them.
      parameters.pop if options.empty?
    end
    force_send
  end

  def self.get_mailer(method_symbol)
    mailer = method_symbol.to_s.camelize.constantize
  end

  def self.essential_notification?(mailer_name)
    return EssentialMailers.include?(mailer_name)
  end

  def self.email_template_disabled?(receiver, mailer)
    program = fetch_receiver_program(receiver)

    program = program.organization if program.is_a?(Program) && mailer.mailer_attributes[:level] == EmailCustomization::Level::ORGANIZATION

    if program.is_a?(Program) || program.is_a?(Organization)
      if program.active?
        program.email_template_disabled_for_activity?(mailer)
      else
        true
      end
    else
      false
    end
  end

  def self.fetch_receiver_program(object)
    if object.is_a?(Array)
      if object.collect(&:class).uniq.size == 1
        object = object.first
      else
        raise "feature.email.error.multiple_type_element_in_array".translate
      end
    end

    if object.is_a?(Program) || object.is_a?(Organization)
      return object
    elsif object.respond_to?(:program)
      return object.program
    elsif object.respond_to?(:organization)
      return object.organization
    elsif object.is_a?(Password)
      # forgot_password
      return object.member.organization
    elsif object.nil?
      # Mails to chronus have no receiver
      return false
    else
      raise "feature.email.error.no_program".translate
    end
  end

  # removes 'deliver_', 'send_', create_' from the method_symbol
  # strip_method_name(:deliver_signup_notification) will result in "signup_notification"
  def self.strip_method_name_from_symbol(method_symbol)
    method_symbol.to_s =~ /[^_]+_(.*)/
    $1
  end
end
