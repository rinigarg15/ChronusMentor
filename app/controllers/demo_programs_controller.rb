
class DemoProgramsController < ApplicationController

  allow :exec => :can_create_demo_programs, :only => [:new, :create]
  before_action :force_back_mark, :only => :new
  before_action :require_super_user
  skip_before_action :login_required_in_program,
                     :require_program,
                     :require_organization
  before_action :validate_parameters, :only => :create

  # it will render new.html.erb
  def new
    @organization = Organization.new
    @program_domain = @organization.program_domains.build
    @program_creation_running = is_currently_executing?
  end

  def create
    unless is_currently_executing?
      @program_subdomain = get_demo_program_subdomain(params[:organization][:program_domain][:subdomain])
      Delayed::Job.enqueue(SalesDemoProgramCreatorJob.new({organization_name: params[:organization][:name], subdomain: @program_subdomain}), priority: DjPriority::SALES_DEMO)
    end
  end

  def check_status
    current_program_creation = Delayed::Job.where(["priority + source_priority = ?", DjPriority::SALES_DEMO]).last
    # Choosing the last DJ because there might be DJs which have failed previously and not destroyed from DB.
    if current_program_creation.blank?
      @subdomain = params[:subdomain]
      raise Exception.new("Invalid Subdomain") if is_invalid_subdomain?(@subdomain)
      @redirection_url = program_root_url(:subdomain => @subdomain)
    elsif current_program_creation.failed_at.present?
      flash[:error] = 'feature.demo_programs.label.error_message'.translate
      @redirection_url = new_demo_program_url
      current_program_creation.update_attribute(:priority, DjPriority::SALES_DEMO_FAILED)
    else
      head :ok
    end
  end

  private
    def validate_parameters
      org_params = params[:organization]
      subdomain = get_demo_program_subdomain(org_params[:program_domain][:subdomain])
      @organization = Organization.new(:name => org_params[:name])
      @program_domain = @organization.program_domains.new(:subdomain => subdomain, :domain => DEFAULT_DOMAIN_NAME)
      @program_domain.organization = @organization
      if !@organization.valid?
        errors = []
        @organization.errors[:name].each do |error_message|
          errors << @organization.errors.full_message(:name, error_message)
        end
        @program_domain.errors[:subdomain].each do |error_message|
          errors << @program_domain.errors.full_message(:subdomain, error_message)
        end
        flash.now[:error] = errors.join(", ")
        render :action => :new
      end
    end

    def is_currently_executing?
      Delayed::Job.exists?(["priority + source_priority = ? and failed_at IS NULL", DjPriority::SALES_DEMO])
    end

    def is_invalid_subdomain?(subdomain)
    	(/^[A-Za-z0-9\-\.]+$/ =~ subdomain).nil?
    end

    def get_demo_program_subdomain(subdomain)
      return "#{subdomain}.demo"
    end

    def can_create_demo_programs
      (defined?(DEMO_PROGRAMS_ALLOWED) && DEMO_PROGRAMS_ALLOWED) ? true : false
    end

end