class DataImportsController < ApplicationController
  PER_PAGE = 10

  skip_before_action :require_program, :login_required_in_program
  before_action :login_required_in_organization
  allow :exec => :has_access?

  def index
    @data_imports = @current_organization.data_imports.recent_first.paginate(:page => params[:page], :per_page => PER_PAGE)
  end

  private

  def has_access?
    wob_member.admin?
  end

end
