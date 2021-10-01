module SearchHelper
  # Types of search results. Each type's value gives the model that it shows
  #   results for, excepting ALL
  FILTER_NAME = "topic"
  module ResultType
    ALL = 'all'
    USERS = 'users'
    GROUPS = 'groups'
    ARTICLES = 'articles'
    ANSWERS = 'qa_questions'
    RESOURCES = 'resources'
    TOPICS = 'topics'
    # Returns the ActiveRecord class associated with the type.
    
    def self.get_class_name(type, program)
      special_class = USERS if program.role_names_without_admin_role.include?(type)
      special_class || type
    end

    # Those types that are related to some model.
    def self.tabs_to_compute_count_for(program, user)
      types = []
      program.role_names_without_admin_role.each do |role_name|
        types << role_name if user.can_view_role?(role_name)
      end
      types << GROUPS if user.can_view_find_new_projects?
      types + feature_tabs_to_compute_count_for(program, user)
    end

    def self.feature_tabs_to_compute_count_for(program, user)
      types = []
      types << ARTICLES if include_article?(program, user)
      types << ANSWERS  if include_qa_question?(program, user)
      types << RESOURCES  if program.has_feature?(FeatureName::RESOURCES) 
      types << TOPICS  if program.has_feature?(FeatureName::FORUMS)
      types
    end

    def self.include_qa_question?(program, user)
      program.has_feature?(FeatureName::ANSWERS) && user.can_view_questions?
    end

    def self.include_article?(program, user)
      program.has_feature?(FeatureName::ARTICLES) && user.can_view_articles?
    end

    # Constraints for fetching records of the given type
    #
    # === Params
    #
    # * <tt>type</tt> : the ResultType for which to compute the constraints
    # * <tt>program</tt> : the program in context
    # * <tt>is_admin_view</tt> : whether the view is for an admin
    #
    def self.constraints_for(type, program, is_admin_view)
      constraints_map = {}
      return constraints_map if type == ResultType::ALL

      constraints_map = {classes: [get_class_name(type, program).classify.constantize]}
      condition_options = {state: User::Status::ACTIVE} unless is_admin_view

      if program.role_names_without_admin_role.include? type
        role_ids = program.get_roles(type).collect(&:id)
        constraints_map.merge!(
          with: {role_ids: role_ids}.merge(condition_options || {})
        )
      end
 
   	  return constraints_map
    end
  end

  # Returns the tab to show for the current request.
  def find_active_tab(view_user_param_names)
    cname, aname, filter_name = params[:controller], params[:action], params[:filter_view]
    case
    when cname == 'programs' && aname == 'search' && filter_name == FILTER_NAME; then ResultType::TOPICS;  
    when cname == 'programs' && aname == 'search'; then ResultType::ALL;
    when cname == 'users' && aname == 'index' && view_user_param_names[params[:view]].present?; then params[:view];
    when cname == 'groups' && aname == 'find_new'; then ResultType::GROUPS;
    when cname == 'articles' && aname == 'index'; then ResultType::ARTICLES;
    when cname == 'qa_questions' && aname == 'index'; then ResultType::ANSWERS;
    when cname == 'resources' && aname == 'index'; then ResultType::RESOURCES;
    end
  end

  def view_param_users(program)
    role_names = program.role_names_without_admin_role
    mapped_role_names = []
    role_names.each do |role_name|
      if role_name == RoleConstants::MENTOR_NAME
        mapped_role_names << RoleConstants::MENTORS_NAME
      elsif role_name == RoleConstants::STUDENT_NAME
        mapped_role_names << RoleConstants::STUDENTS_NAME
      else
        mapped_role_names << role_name
      end
    end
    Hash[role_names.zip mapped_role_names]
  end

  # Renders search category filters
  def category_filters(query, count_map)
    # Map from each type to text to display for for the type.
    type_to_display_name_map  = {
      ResultType::ALL      => "search.categories.All_results".translate,
      ResultType::ARTICLES => _Articles,
      ResultType::ANSWERS  => "search.categories.Questions_and_Answers".translate,
      ResultType::GROUPS   => _Mentoring_Connections,
      ResultType::RESOURCES => _Resources,
      ResultType::TOPICS => "feature.forum.title.forums".translate
    }
    role_names = @current_program.role_names_without_admin_role
    view_param_role_names = view_param_users(@current_program)
    content = "".html_safe
    active_tab = find_active_tab(view_param_role_names)
    # Do not render tabs for empty results
    return content if active_tab == ResultType::ALL && @results.empty?

    all_results_count = 0
    # Render tabs if applicable.
    if active_tab
      items = []
      items << {
        :text => type_to_display_name_map[ResultType::ALL],
        :url => search_path(:query => query)
      }
      #pluralized_terms = []
      role_names.each do |role_name|
        if current_user.can_view_role?(role_name)
          options_hash = {:search => query}
          # if the role name is student => view=students if role name is teacher => view=teacher if role name is mentor view=mentors Using this because it makes more sense
          options_hash.merge!({:view => view_param_role_names[role_name], src: EngagementIndex::Src::BrowseMentors::SEARCH_BOX })
          customized_role_term = @current_program.roles_without_admin_role.find { |role| role.name == role_name }.customized_term
          #pluralized_terms << customized_role_term.pluralized_term
          items << {
            :text => customized_role_term.pluralized_term,
            :count => count_map[role_name],
            :url => users_path(options_hash),
            :disabled => count_map[role_name] == 0
          }
          all_results_count += count_map[role_name]
        end
      end

      if current_user.can_view_find_new_projects?
        items << {
          :text => type_to_display_name_map[ResultType::GROUPS],
          :count => count_map[ResultType::GROUPS],
          :url => find_new_groups_path(:search => query),
          :disabled => count_map[ResultType::GROUPS] == 0
        }
        all_results_count += count_map[ResultType::GROUPS]
      end
     
      category_filters_features!(type_to_display_name_map, count_map, items, @current_program, FeatureName::ARTICLES, ResultType::ARTICLES, articles_path(search: query)) if current_user.can_view_articles?
      
      category_filters_features!(type_to_display_name_map, count_map, items, @current_program, FeatureName::ANSWERS, ResultType::ANSWERS, qa_questions_path(search: query)) if current_user.can_view_questions?
      
      category_filters_features!(type_to_display_name_map, count_map, items, @current_program, FeatureName::RESOURCES, ResultType::RESOURCES, resources_path(search: query))

      category_filters_features!(type_to_display_name_map, count_map, items, @current_program, FeatureName::FORUMS, ResultType::TOPICS, search_path(query: query, filter_view: FILTER_NAME))

      all_results_count += (count_map[ResultType::ARTICLES].to_i + count_map[ResultType::ANSWERS].to_i + count_map[ResultType::RESOURCES].to_i + count_map[ResultType::TOPICS].to_i)

      items[0][:count] = all_results_count
      selected_item = type_to_display_name_map[active_tab] || @current_program.roles_without_admin_role.find_by(name: view_param_role_names.invert[active_tab]).customized_term.pluralized_term
      content << content_tag(:div, vertical_filters(selected_item, items))
    end

    if content.present?
      mobile_footer_actions = { see_n_results: { results_count: items.find { |item| item[:text] == selected_item }[:count] } }
      return filter_container_wrapper(mobile_footer_actions, append_text_to_icon("fa fa-filter", "display_string.Filters".translate)) do
        content
      end
    else
      "".html_safe
    end
  end

  def category_filters_features!(type_to_display_name_map, count_map, items, program, feature, result_type, url)
    if program.has_feature?(feature)
      items << {
        text: type_to_display_name_map[result_type],
        count: count_map[result_type],
        url:  url,
        disabled: (count_map[result_type] == 0)
      }
    end 
  end

  # Renders search title, tabs and other elements and wraps the block inside
  # them.
  def search_results_wrapper(query, other_filters = '', &block)
    # Not search view if no query is given or empty results.
    yield and return unless (query && logged_in_program?)
    @title = "feature.search.header.query_results_html".translate(query: query)
    @no_page_actions = true
    content = "".html_safe
    count_map = result_count_per_category(query)

    # Empty results
    if count_map.values.sum == 0
      content = capture(&block)
    else
      content_for_sidebar do
        category_filters(query, count_map) + other_filters
      end
      content << content_tag(:div, :class => 'vertical_filters_wrapper clearfix') do
        capture(&block)
      end
    end

    controller.activate_tab(controller.tab_info[TabConstants::HOME])
    content = content_tag(:div, content, :id => 'search_view')
    concat(content, &block)
  end

  # Computes the number of results for the query for each result type.
  def result_count_per_category(query)
    count_map = {}

    admin_view = current_user.is_admin?
    # Count for each result type, scoping to that type's class
    ResultType.tabs_to_compute_count_for(@current_program, current_user).each do |result_type|
      type_constraints = ResultType.constraints_for(result_type, @current_program, admin_view)

      # Restrict to the program from within which the page is viewed.
      with_options = {program_id: @current_program.id}

      group_status = if current_user.can_send_project_request?
        Group::Status::OPEN_CRITERIA
      else
        Group::Status::ACTIVE_CRITERIA
      end
      with_options.merge!(group_status: group_status)
      type_constraints[:admin_view_check] = admin_view
      type_constraints[:current_user_role_ids] = global_search_current_user_role_ids  
      (type_constraints[:with] ||= {}).merge!(with_options)
      count_map[result_type] = GlobalSearchElasticsearchQueries.new.count(query, type_constraints)
    end

    return count_map
  end
end
