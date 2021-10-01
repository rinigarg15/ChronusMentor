#
# Management of organization administrators
#
class OrganizationAdminsController < ApplicationController
  skip_before_action :require_program, :login_required_in_program
  before_action :login_required_in_organization

  allow :exec => :check_access
  before_action :get_admin, :only => [:destroy]
  allow :exec => :check_program_owner, :only => [:destroy]

  def index
    @admins = @current_organization.members.admins
    @new_admin = @current_organization.members.new
    deserialize_from_session(Member, @new_admin, :admin)
  end

  def create
    if params[:member][:name_with_email]
      email = Member.extract_email_from_name_with_email(params[:member][:name_with_email] || "")
      @member = @current_organization.members.find_by(email: email)
      if @member
        is_dormant = @member.dormant?
        @member.promote_as_admin!
        if is_dormant
          reset_password = Password.create!(:member => @member)
          ChronusMailer.admin_added_notification(@member, wob_member, params[:message], reset_password).deliver_now
        else        
          ChronusMailer.user_promoted_to_admin_notification(@member, wob_member).deliver_now
        end
        flash[:notice] =  "flash_message.organization_admin_flash.promoted_v1".translate(member: @member.name(name_only: true), admins: _admins)
      else
        # No such user. Report the same.
        flash[:error] = "flash_message.organization_admin_flash.not_found".translate
      end
    else
      @new_admin = @current_organization.members.build(organization_admins_params(:create))
      if @new_admin.save
        @new_admin.promote_as_admin!
        reset_password = Password.create!(:member => @new_admin)
        ChronusMailer.admin_added_notification(@new_admin, wob_member, params[:message], reset_password).deliver_now
        flash[:notice] =  "flash_message.organization_admin_flash.promoted_v1".translate(member: @new_admin.name(name_only: true), admins: _admins)
      else
        serialize_to_session(@new_admin)
        flash[:error] = "common_text.error_msg.please_correct_highlighted_errors".translate
      end
    end

    redirect_to organization_admins_path
  end

  def destroy
    @admin.demote_from_admin!
    flash[:notice] = "flash_message.organization_admin_flash.demoted_v1".translate(member: @admin.name(name_only: true), admins: _admins)
    redirect_to organization_admins_path
  end

private

  def organization_admins_params(action)
    params.require(:member).permit(Member::MASS_UPDATE_ATTRIBUTES[:from_organization_admin][action])
  end

  def check_access
    wob_member.admin?
  end

  def check_program_owner
    @admin.no_owner_in_organization?
  end

  def get_admin
    @admin = @current_organization.members.admins.find(params[:id])
  end

end
