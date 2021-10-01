class HomeController < ApplicationController
  include ActiveAdmins
  before_action :require_super_user, :only => [:default, :organizations, :csreport, :export_admins, :deactivate, :solution_packs, :feature_report, :inline_edit_organizations]
  skip_before_action :login_required_in_program, :require_program, :require_organization
  skip_before_action :load_current_organization, :load_current_root, :load_current_program, :configure_program_tabs, :configure_mobile_tabs, :only => [:default, :organizations, :csreport, :export_admins, :feature_report]
  skip_before_action :back_mark_pages, :except => [:default, :organizations, :export_admins, :csreport, :solution_packs, :feature_report]
  skip_before_action :handle_pending_profile_or_unanswered_required_qs, :only => [:privacy_policy, :terms]
  skip_before_action :handle_terms_and_conditions_acceptance, only: [:terms, :privacy_policy]
  skip_before_action :check_browser, only: [:upgrade_browser]

  newrelic_ignore_apdex :only => [:organizations, :csreport, :feature_report]

  def default
    @program = Program.new
    @organization = @program.build_organization
    @program_domain = @organization.program_domains.build()
    @program_domain.domain = DEFAULT_DOMAIN_NAME
  end

  def export_admins
    @admins = pull_active_admins

    #If CSV request
    if (request.format == Mime[:csv])
      send_csv get_admins_in_csv(@admins),
        :disposition => "attachment; filename=#{"feature.admin_view.label.admins_csv_report_name".translate(date: DateTime.localize(Time.current, format: :csv_timestamp))}.csv"
    end
  end

  def organizations
    @organizations = Organization.select(:id, :programs_count, :active, :created_at, :account_name).includes(:translations)
    @admins = Member.admins.select(:email, :organization_id).group_by(&:organization_id)
    @member_count = Member.group(:organization_id).count
    @inline_edit = true if params[:edit]
    @active_member_count = Member.joins(:users).where(users: {state: User::Status::ACTIVE}).distinct.group("members.organization_id").count
    @org_last_seen_at_map = User.joins(:member).select("max(users.last_seen_at) as last_seen_at, members.organization_id as org_id").group("members.organization_id").group_by(&:org_id)

    respond_to do |format|
      format.html {}
      format.csv do
        report_file_name = "OrgsReport_#{Rails.env}_#{DateTime.localize(Time.now, format: :report_timestamp)}".to_html_id
        send_csv generate_orgs_csv, disposition: "attachment; filename=#{report_file_name}.csv"
      end
    end
  end

  def inline_edit_organizations
    @organization = Organization.find_by(id: params[:id])
    @organization.update_attributes(account_name: params[:account_name])
    render :json => {:status => 'ok'}
  end

  def solution_packs
    @solution_packs = SolutionPack.all
  end

  def deactivate
  end

  def upgrade_browser
    @no_tabs = true
    redirect_to root_path and return unless is_unsupported_browser?
    set_browser_warning_content
  end

  def notify_new_timezone
    # An airbrake is triggered whenever js detects new timezone that is not in TimezoneConstants::VALID_TIMEZONE_IDENTIFIERS
    # Update tzinfo-data gem and run 'rake tz:handle_tzinfo_update' to handle new timezones.
    notify_airbrake(StandardError.new("New TZ Detected: #{params[:detected_timezone]}")) if params[:detected_timezone]
    head :ok
  end

  def csreport
    time_period_1 = params[:week] ? 1.week : 1.month
    time_period_2 = params[:week] ? 1.month : 3.months
    active = params[:closed] ? false : true

    @csreport = HealthReport::ChronusHealthReport.new(time_period_1, time_period_2, active)
    @csreport.compute_data()


    respond_to do |format|
      format.html {}
      format.csv do
        report_file_name = "CSReport_#{DateTime.localize(Time.now, format: :report_timestamp)}".to_html_id
        send_csv @csreport.generate_csv(params[:week] ? 'week' : 'month', params[:week] ? 'month' : 'quarter'), disposition: "attachment; filename=#{report_file_name}.csv"
      end
    end
  end

  def feature_report
    respond_to do |format|
      format.html do
      end
      format.json do
        header = [
          {field: "program_id", displayName: "feature.reports.report_listing.column.program_id".translate, minWidth: 50},
          {field: "organization_id", displayName: "feature.reports.report_listing.column.organization_id".translate, minWidth: 50},
          {field: "active", displayName: "feature.reports.report_listing.column.active".translate, minWidth: 50},
          {field: "program_name", displayName: "feature.reports.report_listing.column.program_name".translate, minWidth: 150},
          {field: "organization_name", displayName: "feature.reports.report_listing.column.organization_name".translate, minWidth: 150},
          {field: "account_name", displayName: "feature.reports.report_listing.column.account_name".translate, minWidth: 70}
        ]
        pinned_header_length = header.length
        Feature.all.each do |f|
          feature_column = {field: dehumanize_feature_name(f.name), pinned: false, minWidth: 100}
          header << feature_column
        end
        all_program_array = []
        Program.all.each do |p|
          subarray = {program_id: p.id.to_s, organization_id: p.organization.id.to_s, active: p.organization.active.to_s, program_name: p.name, organization_name: p.organization.name, account_name: p.organization.account_name}
          Feature.all.each do |f|
            subarray[dehumanize_feature_name(f.name)] = p.has_feature?(f.name).to_s
          end
          all_program_array << subarray
          subarray = {}
        end
        render :json => {header: header, all_program_array: all_program_array, pinned_header_length: pinned_header_length}.to_json and return
      end

      format.csv do
        send_csv Feature.generate_csv, disposition: "attachment; filename=feature_report.csv"
      end
    end
  end

  # Privacy Policy page.
  # If program specific Privacy Policy is present, renders two tabs one for program privacy policy
  # and other for Chronus privacy policy.
  #
  # ==== Params
  # * <tt>p</tt> : if present, renders program's Privacy Policy
  #

  def privacy_policy
    @program_privacy = @current_organization && @current_organization.privacy_policy
    @is_program_privacy = params[:p] && @program_privacy.present?
  end

  # Terms & Conditions page.
  # If program specific terms are present, renders a single page with both terms of org and customer unless display_custom_terms_only flag is enabled in which case we show their terms only

  def terms
  end

  def handle_redirect
    @redirect_path = CGI.unescape(params[:redirect_path])
    @use_browsertab = use_browsertab_for_external_link?(@redirect_path)
  end

  private

  def dehumanize_feature_name(feature_name)
    feature_name.downcase.gsub(/ +/,'_')
  end

  def generate_orgs_csv
    CSV.generate do |csv|
      header = ["Account Name", "Name", "Url", "Status", "Tracks Count", "Members active atleast in one track", "Total Members", "Administrators", "Created", "Last Login"]
      csv << header

      @organizations.each do |org|
        status = org.active ? 'Active' : 'Closed'
        last_seen_at = @org_last_seen_at_map[org.id].last.last_seen_at.present? ? DateTime.localize(@org_last_seen_at_map[org.id].last.last_seen_at, format: :abbr_short) : "Inactive"
        subarray = [
          org.account_name, org.name, root_organization_url(:domain => org.domain, :subdomain => org.subdomain, protocol: org.get_protocol), status, org.tracks.size, @active_member_count[org.id], 
          @member_count[org.id], @admins[org.id].collect(&:email).join(","), DateTime.localize(org.created_at, format: :abbr_short), last_seen_at
        ]
        csv << subarray
        subarray = []
      end
      csv
    end
  end

end
