class AbTestsController < ApplicationController
  skip_before_action :require_program, :login_required_in_program
  before_action :login_required_in_organization
  before_action :require_super_user
  allow :exec =>  :logged_in_at_current_level?

  def index
  end

  def update_for_program
    ProgramAbTest.experiments.each do |experiment|
      current_program_or_organization.enable_ab_test(experiment, (params[:experiments]||[]).include?(experiment))
    end
    flash[:notice] = "flash_message.ab_tests.success".translate
    redirect_to ab_tests_path
  end
end