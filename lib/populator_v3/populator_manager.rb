require_relative './../../demo/code/demo_helper'
class PopulatorManager < DataPopulator
  SPEC_PATH = Rails.root + 'lib/populator_v3/config/spec_config.yml'
  ROOT_NODE = 'organization'
  PROGRAM_NODE = 'program'
  IGNORE_LIST = ["organization", "organization_common", "group_mentoring_common"]

  attr_accessor :nodes, :ignore_list, :traverse_order, :graph

  def initialize(options = {})
    @graph = {}
    @ignore_list = IGNORE_LIST
    @nodes =  YAML.load_file(options[:spec_file_path].presence || SPEC_PATH)
    @traverse_order = []
    @display = PopulatorV3Dashboard.new(screen: (options[:screen]))
    @display.refresh(status: "Initializing", progress_total: 79, progress: 1)
    @categorized_organizations = {}
  end

  def get_class(node)
    (@nodes[node]["model"] || node).camelize.constantize
  end

  def populate
    @display.refresh(status: "Entering populate")
    suspend_services do
      build_graph
      build_traverse_order
      populate_tags
      patch_organizations
    end
    @display.refresh(status: "DONE")
  end

  def suspend_services
    @display.refresh(status: "Suspending service")
    orig_action_mailer = ActionMailer::Base.perform_deliveries
    ActionMailer::Base.perform_deliveries = false
    orig_delayed_job = Delayed::Worker.delay_jobs
    Delayed::Worker.delay_jobs = false
    Object.send :alias_method, :send_later, :send
    Object.class_eval do
      def send_at(time, method, *args)
        send(method, *args)
      end
    end

    orig_elastic_search = ChronusElasticsearch.skip_es_index
    ChronusElasticsearch.skip_es_index = true
    yield
    @display.refresh(status: "Resuming service")
    # Object.class_eval{undef send_at} # revisit later
    # Object.class_eval{undef send_later} # revisit later
    ActionMailer::Base.perform_deliveries = orig_action_mailer
    Delayed::Worker.delay_jobs = orig_delayed_job
    ChronusElasticsearch.skip_es_index = orig_elastic_search
    @display.refresh(status: "Matching Index")
    # Rake::Task["matching:clear_and_full_index_and_refresh"].invoke # Need to call a bg process for 'rake matching:full_index_and_refresh'
  end

  def build_graph
    @display.refresh(status: "Building graph")
    nodes = @nodes.clone
    @ignore_list.each do |node|
      nodes.delete(node)
    end
    nodes.keys.each do |node|
      parent = @nodes[node]["parent"]
      @graph[parent] = @graph[parent] ? @graph[parent].append(node) : [node]
    end
  end

  def build_traverse_order
    @display.refresh(status: "Building traverse order")
    queue = [ROOT_NODE]
    visited_list = {}
    @nodes.keys.map{|key| visited_list[key] = false }
    safety_counter = 0

    until queue.empty?
      current = queue.shift
      if dependency_satisfied?(current, visited_list) && parent_visited(current, visited_list)
        @traverse_order << current
        children = @graph[current]
        queue += children if children
        visited_list[current] = true
      else
        queue.push(current)
      end
      safety_counter += 1
      raise "Stuck in build_traverse_order (queue: #{queue.inspect}, current: #{current})" if safety_counter > 1000
    end
  end

  def populate_tags
    unless ActsAsTaggableOn::Tag.where("name like 'perfv3_%'").pluck(:id).present?
      tag_names = ['app', 'code', 'design', 'ruby', 'flow', 'gem', 'science', 'script', 'math', 'map']
      ActsAsTaggableOn::Tag.populate(tag_names.size) do |tag|
        tag.name ='perfv3_' + tag_names.shift
      end
    end
  end

  def patch_organizations
    @categorized_organizations = {}
    categories = @nodes["organization"].keys
    program_domains = Program::Domain.all
    categories.each do |category|
      @categorized_organizations[category] = program_domains.select{|pd| pd.subdomain && pd.subdomain.match(category)}.map{|pd| pd.organization}
    end
    fill_organizations_and_programs
  end

  # In future need to rescale/replace instead of create/delete for every org category and note this while adding code
  def fill_organizations_and_programs
    count_from_spec = @nodes["organization"].values.map{|org| org["count"]}
    (@categorized_organizations.keys - ["scope"]).each do |category|
      count_difference = @nodes["organization"][category]["count"] - @categorized_organizations[category].try(:size).to_i
      if count_difference > 0
        count_difference.times do |count|
          org_number =  @categorized_organizations[category].last ? @categorized_organizations[category].last.subdomain.split(category).last.to_i.next : 1
          org_name = "Organization #{category} #{org_number}"
          org_subdomain = "#{category}#{org_number}"
          organization = fill_organization(category, org_name, org_subdomain)
          @categorized_organizations[category] =  @categorized_organizations[category] ? @categorized_organizations[category].append(organization) : [organization]
        end
      elsif count_difference < 0
        @categorized_organizations[category].last(count_difference.abs).each{|org| org.destroy}
        @categorized_organizations[category] = @categorized_organizations[category][0..count_difference-1]
      end
    end
    programs_count = @nodes["organization_common"]["programs_count"]
    fill_programs
    populator_for_each_organization
  end

  def populator_for_each_organization
    @traverse_order -= ["organization", "program"] # since org and prog creation/deletion is handled by manager
    role_hash = {}
    @categorized_organizations.each do |key, value|
      orgs_count_in_category = value.size
      current_count_index = Array.new(@traverse_order.size, 0)
      value.each_with_index do |org, org_index|
        @traverse_order.each_with_index do |node, index|
          puts "Visiting #{node} (Progress: #{index+1}/#{@traverse_order.size})"
          if @nodes[node]["parent"] == ROOT_NODE && node !="member"
            current_count_index[index] = update_count(orgs_count_in_category, org_index, @nodes[node]["percent"], current_count_index[index])
            counts_ary = [@nodes[node]["count"][current_count_index[index]]]
            percents_ary = [100]
          end
          options = {:organization => org, :args => @nodes[node], :common => @nodes["organization"][key], :org_node => @nodes["organization"], :counts_ary => counts_ary || @nodes[node]["count"], :percents_ary => percents_ary || @nodes[node]["percent"], :scope => @nodes["scope"], display: @display}
          populator_task = PopulatorTask.new(node, options)
          @display.refresh(status: "Updating node : #{node}")
          populator_task.delegate_work
        end
      end
    end
  end

  def dependency_satisfied?(node, visited_list)
    @nodes[node]["dependency"] ? @nodes[node]["dependency"].map{|dep| visited_list[dep]}.all? : true
  end

  def fill_organization(category, name, subdomain)
    Feature.create_default_features
    Permission.create_default_permissions
    ActionMailer::Base.perform_deliveries = false
    options = {
      allow_one_to_many_mentoring: true,
      subscription_type: ENV['SUBSCRIPTION_STYLE'] || Organization::SubscriptionType::ENTERPRISE,
      mentor_request_style: ENV['MENTOR_REQUEST_STYLE'] || Program::MentorRequestStyle::MENTEE_TO_MENTOR
    }
    puts "*** Creating Organization with subdomain #{subdomain}****"
    organization = create_organization(name, subdomain, options)
  end

  def fill_programs
    categories = @nodes[ROOT_NODE].keys
    categories.each do |category|
      @categorized_organizations[category].each do |organization|
        organization.enable_feature(FeatureName::CAREER_DEVELOPMENT) if @nodes[ROOT_NODE][category]["portals_count"] > 0
        add_or_remove_programs(organization, category, organization.tracks, @nodes[ROOT_NODE][category]["programs_count"], Program)
        add_or_remove_programs(organization, category, organization.portals, @nodes[ROOT_NODE][category]["portals_count"], CareerDev::Portal)
      end
    end
  end

  def add_or_remove_programs(organization, category, existing_programs, target_count, program_klass)
    diff = target_count - existing_programs.size
    if diff > 0
      create_program_for_organization(organization, diff, category, program_klass)
    elsif diff < 0
      raise "Cannot downscale programs yet"
      existing_programs.last(diff.abs).each do |program|
        program.active = false
        program.save!
        program.destroy
      end
    end
  end

  def create_organization(name, subdomain, options = {})
    organization = nil
    project_based = options[:engagement_type] == Program::EngagementType::PROJECT_BASED
    PopulatorTask.benchmark_wrapper "Organization" do
      organization = Organization.new
      organization.name = name
      organization.account_name = name + " account"
      organization.subscription_type = options[:subscription_type] || Organization::SubscriptionType::PREMIUM
      organization.created_at = Time.at(rand((30.days.ago).to_i .. (15.days.ago).to_i))
      organization.save!
      DataPopulator.populate_default_contents(organization)

      pdomain = organization.program_domains.new()
      pdomain.subdomain = subdomain
      pdomain.domain = DEFAULT_DOMAIN_NAME
      pdomain.save!

      Organization.skip_timestamping do
        update_demo_features(organization)
        if organization.subscription_type.to_i == Organization::SubscriptionType::ENTERPRISE
          organization.enable_feature(FeatureName::CALENDAR) unless project_based
          organization.enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
        end
        ProgramAsset.find_or_create_by(:program_id => organization.id)
        organization.program_asset.logo = Rack::Test::UploadedFile.new(demo_file("pictures", "chronus_logo.jpg"), 'image/jpg', true)
        organization.program_asset.save
        Feature.handle_feature_dependency(organization)
        DataPopulator.populate_default_contents(organization)
        organization.assign_default_theme
        organization.save!
        populate_theme(organization, options[:theme_name], options[:theme_css])
      end
      dot
      PopulatorTask.display_populated_count(1, "Organization")
    end
    organization
  end

  def create_program_for_organization(organization, program_count, category, program_klass)
    engagement_type = @nodes["organization"][category]["engagement_type"].constantize if @nodes["organization"][category]["engagement_type"].present?
    options = {:engagement_type => engagement_type}
    count = organization.programs.count
    klass_name = program_klass.name
    PopulatorTask.benchmark_wrapper klass_name do
      program_count.times do |index|
        options[:program_name] = "#{klass_name.gsub('::', ' ')} #{count+index+1}"
        options[:description] = Populator.sentences(1..2)
        options[:created_at] = Time.at(rand((organization.created_at).to_i..(10.days.ago).to_i))
        options[:engagement_type] = Program::EngagementType::CAREER_BASED if category == "onlyflashga"
        program = send("create_#{klass_name.demodulize.downcase}", organization, count+index+1, options)
        program.reload
        dot
      end
      PopulatorTask.display_populated_count(program_count, klass_name)
    end
    create_admin(organization)
  end

  def create_admin(organization)
    program = organization.reload.programs.first
    admin = program.users.includes(:member).where("members.admin = true").order("members.id").first
    admin ||= create_program_admin(program)[:user]
    assign_owner!(organization.programs, admin)
  end

  def parent_visited(node, visited_list)
    node && @nodes[node]["parent"] ? visited_list[@nodes[node]["parent"]] : true
  end

  def update_count(total, current, percents_ary, current_count_index)
    adjusted_percent_ary = percents_ary.map { |percent| (percent.is_a?(Array) ? percent[0] : percent) }
    current_percent = ((current.to_f / total.to_f )*100).to_i
    current_percent -= adjusted_percent_ary[(0..(current_count_index -1))].sum if current_count_index > 0
    current_count_index += 1 if adjusted_percent_ary[current_count_index] < current_percent
    current_count_index
  end
end
