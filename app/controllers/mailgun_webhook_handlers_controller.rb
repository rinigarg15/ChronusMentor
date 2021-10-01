class MailgunWebhookHandlersController < ApplicationController
  include AuthenticationForExternalServices

  MEMBER_STATUS_MAP = {
    Member::Status::ACTIVE => "Active",
    Member::Status::DORMANT => "Dormant",
    Member::Status::SUSPENDED => "Suspended"
  }

  skip_before_action :login_required_in_program, :require_program, :require_organization, :back_mark_pages, :handle_pending_profile_or_unanswered_required_qs, :verify_authenticity_token
  before_action :verify_signature

  def handle_events
    # Collect the analytics for campaigns
    notify_chronus(params)
    head :ok
  end

  private

  def verify_signature
    unless mailgun_signature_verified?
      render plain: 'Invalid signature', status: HttpConstants::FORBIDDEN
    end
  end


  # Notify chronus of bounced and spammed events
  def notify_chronus(params)
    recipient_email = params[:recipient]

    # Campaing information
    campaign_information = {}
    campaign_information[:name] = params["campaign-name"] if params["campaign-name"]
    campaign_information[:id] = params["campaign-id"] if params["campaign-id"]
    # Member information
    member = Member.find_by(email: recipient_email)
    member_information = {}
    member_information[:organization] = member.try(:organization).try(:url) if member.try(:organization)
    member_information[:state] = MEMBER_STATUS_MAP[member.try(:state)] if member.try(:state)
    case params[:event]
    when ChronusMentorMailgun::Event::BOUNCED
      #SMTP bounce error string.
      bounce_reason = {}
      bounce_reason[:error_message] = params[:error] if params[:error]
      #SMTP bounce error code in form (X.X.X).
      bounce_reason[:code] = params[:code] if params[:code]
      #Detailed reason for bouncing.
      bounce_reason[:detailed_reasoning] = params[:notification] if params[:notification]
      InternalMailer.bounced_mail_notification(recipient_email, bounce_reason, campaign_information,member_information).deliver_now
    when ChronusMentorMailgun::Event::SPAMMED
      InternalMailer.marked_as_spam_notification(recipient_email, campaign_information,member_information).deliver_now
    end
  end

end