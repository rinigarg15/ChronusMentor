class CkPicturesController < ApplicationController
  skip_before_action :require_program, :login_required_in_program, :back_mark_pages, :handle_pending_profile_or_unanswered_required_qs, :handle_terms_and_conditions_acceptance
  allow :exec => :authorize_show, :only => [:show]

  def show
    if @picture.present? && @picture.data.exists?
      if @picture.organization.security_setting.sanitization_version == ChronusSanitization::HelperMethods::SANITIZATION_VERSION_V2
        @no_handle_redirect = true
        redirect_to @picture.data.url
      else
        data = open(URI.parse(@picture.data.url))
        send_data(data.read, filename: @picture.data_file_name, type: @picture.data_content_type, disposition: "inline")
      end
    else
      head :ok
    end
  end

  private

  def authorize_show
    @picture = Ckeditor.picture_model.find_by(id: params[:id], program_id: @current_organization.id)
    if logged_in_organization? || !@picture.present? || !@picture.login_required?
      return true
    elsif @picture.present? && @picture.login_required?
      flash[:notice] = "flash_message.ck_attachments.login_required".translate
      session[:ck_attachment_url] = request.url
      session[:ck_attachment_set_time] = Time.now
      redirect_to new_session_path and return true
    end
  end
end