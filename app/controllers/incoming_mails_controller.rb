class IncomingMailsController < ApplicationController
  include AuthenticationForExternalServices

  skip_before_action :login_required_in_program, :require_program, :require_organization
  skip_before_action :back_mark_pages, :handle_pending_profile_or_unanswered_required_qs
  before_action :save_message, :verify_signature, :verify_receiver
  skip_before_action :verify_authenticity_token

  def create
    content = params['stripped-text'].presence
    signature = params['stripped-signature'].presence
    if content.present?
      content = content + "\n" + signature if signature
      subject = params['Subject'].to_s
      receiver_split = @recipient_email.split(/[+@]/)
      obj_type = receiver_split[2]
      obj_id = receiver_split[1]

      if(obj_type == ReplyViaEmail::SCRAP)
        original_receiver = Connection::Membership.find_by(api_token: obj_id)
        receiver_email = original_receiver.present? ? original_receiver.user.email : ''
      elsif reply_via_message?(obj_type)
        receiver = AbstractMessageReceiver.find_by(api_token: obj_id)
        original_receiver = (receiver.present? && receiver.message.is_a?(Message)) ? Messages::Receiver.find_by(api_token: obj_id) : Scraps::Receiver.find_by(api_token: obj_id)
        receiver_member = original_receiver.try(:member)
        receiver_email = receiver_member.try(:email).to_s
        original_receiver = get_correct_message_receiver(original_receiver, sender_email) if in_error_period?(original_receiver)
      elsif(obj_type == ReplyViaEmail::ADMIN_MESSAGE)
        original_receiver = AdminMessages::Receiver.find_by(api_token: obj_id)
        receiver_member = original_receiver.try(:member)
        receiver_email = receiver_member.try(:email).to_s
        original_receiver = get_correct_message_receiver(original_receiver, sender_email) if in_error_period?(original_receiver)
      elsif ReplyViaEmail.get_reply_to_meeting_emails.include?(obj_type)
        api_tokens = obj_id.split('-')
        original_receiver = MemberMeeting.find_by(api_token: api_tokens[1])
        original_sender_member = MemberMeeting.find_by(api_token: api_tokens[0]).try(:member)
        receiver_member = original_receiver.try(:member)
        receiver_email = receiver_member.try(:email).to_s
      else
        @received_message.update_attribute(:response, ReceivedMail::Response.invalid_object_type)
      end

      if original_receiver.present?
        options = {content: content, subject: subject, sender_email: sender_email}
        options.merge!({obj_type: obj_type, original_sender_member: original_sender_member}) if ReplyViaEmail.get_reply_to_meeting_emails.include?(obj_type)
        replied_via_email = original_receiver.handle_reply_via_email(options)
        track_reply_via_message(original_receiver, receiver_member) if replied_via_email && reply_via_message?(obj_type)

        @received_message.update_attribute(:response, ReceivedMail::Response.successfully_accepted)
        @received_message.update_attribute(:sender_match, false) unless sender_email == receiver_email
      else
        @received_message.update_attribute(:response, ReceivedMail::Response.invalid_api_token) unless @received_message.response == ReceivedMail::Response.invalid_object_type
      end

    else
      @received_message.update_attribute(:response, ReceivedMail::Response.no_content)
    end
    head :ok
  end

  protected

  def reply_via_message?(obj_type)
    return (obj_type == ReplyViaEmail::MESSAGE)
  end

  def track_reply_via_message(receiver, receiver_member)
    message = receiver.message
    program = message.context_program
    user = receiver_member.user_in_program(program)
    
    if message.is_a?(Message)
      track_sessionless_activity_for_ei(EngagementIndex::Activity::REPLY_USERS, receiver_member, receiver_member.organization, {:context_place => EngagementIndex::Src::ReplyUsers::EMAIL, user: user, program: program, browser: browser})
    elsif message.is_group_message?
      track_sessionless_activity_for_ei(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA, receiver_member, receiver_member.organization, {user: user, program: program, browser: browser})
    end
  end

  def in_error_period?(message_receiver)
    start_time = DateTime.parse('26th September 2016')
    end_time = DateTime.parse('30th September 2016')
    message_receiver.present? && message_receiver.created_at > start_time && message_receiver.created_at < end_time
  end

  def get_correct_message_receiver(old_message_receiver, sender_email)
    return nil unless old_message_receiver.present?
    org = get_organization(old_message_receiver)
    member = org.members.find_by(email: sender_email)
    member.present? ? get_valid_message_receiver_for_member(member, old_message_receiver) : old_message_receiver
  end

  def get_organization(message_receiver)
    program = message_receiver.message.program
    program.present? && program.is_a?(Program) ? program.organization : program
  end

  def get_valid_message_receiver_for_member(member, old_message_receiver)
    valid_message_receiver = old_message_receiver.message.message_receivers.find_by(member_id: member.id)
    valid_message_receiver.present? ? valid_message_receiver : old_message_receiver
  end

  def verify_signature
    unless mailgun_signature_verified?
      @received_message.update_attribute(:response, ReceivedMail::Response.invalid_signature)
      render plain: 'activerecord.custom_errors.incoming_mail.invalid_signature'.translate, status: 403
    end
  end

  def save_message
    attachment_count = params['attachment-count']
    if attachment_count.present?
      1.upto(attachment_count.to_i) do |i|
        request.request_parameters.delete("attachment-#{i}")
      end
    end
    ## saving every thing that is being sent first so that even if there are bugs in the code we at least will have the data
    if not_saved
      data_hash = Hash.new
      request.request_parameters.each do |key,value|
        data_hash[key] = value
      end
      data = Marshal.dump(data_hash)
      @received_message = ReceivedMail.create!(message_id: params['Message-Id'],
                           stripped_text: params['stripped-text'],
                           from_email: params['From'],
                           to_email: params['To'],
                           data: data)
    else
      if ReceivedMail.find_by(message_id: params['Message-Id']).response == ReceivedMail::Response.invalid_signature
        ## Some one might be trying to attack us
        render plain: 'activerecord.custom_errors.incoming_mail.invalid_signature'.translate, status: 403
      else
        ## If previously received this mail and valid signature then send success message
        render plain: 'activerecord.custom_errors.incoming_mail.mail_received_previously'.translate, status: 200
      end
    end
  end

  def get_recipient_email(mail_list, reply_to_list)
    @recipient_email = mail_list.scan(/\b(#{reply_to_list.join("|")})([A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4})\b/i).first.try(:join)
  end

  def verify_receiver
    ## receiver should look like reply+number+number@m.chronus.com
    reply_to_list = APP_CONFIG[:reply_to_migrated_environments] || []
    reply_to_list << APP_CONFIG[:reply_to_email_username]
    if params['To'].present?
      @recipient_email = get_recipient_email(params['To'],reply_to_list)
    end

    receiver_split = @recipient_email.present? ? @recipient_email.split(/[+@]/) : []
    expected_receivers = reply_to_list.map { |receiver| "#{receiver.strip}@m.chronus.com" }
    unless ((receiver_split.size == 4) && (expected_receivers.include?(receiver_split.first+'@'+receiver_split.last)))
      @received_message.update_attribute(:response, ReceivedMail::Response.invalid_receiver)
      render plain: 'activerecord.custom_errors.incoming_mail.received_but_rejected'.translate, status: 200 # Set 200 success OK status
    end
  end

  def not_saved
    !ReceivedMail.find_by(message_id: params['Message-Id']).present?
    ## params['Message-Id'].present? is not being checked as for all practical purposes messages without Message-Id are treated as spam
  end

  def sender_email
    params[:from].present? ? params[:from].scan(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b/i).first : nil #removing name and having only email
  end
end