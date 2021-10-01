class UserProfileFilterService
  include Geokit::Geocoders
  extend DateProfileFilter
  attr_reader :filter_questions, :in_summary_questions, :profile_questions, :profile_filterable_questions, :non_profile_filterable_questions, :custom_profile_filters

  def initialize(program, current_user, roles)
    @current_program = program
    @current_user = current_user
    @roles = roles

    initialize_filterable_and_summary_questions
  end

  class << self
    def get_profile_filters_to_be_applied(search_filters)
      custom_profile_filters = {}
      if search_filters.present? && search_filters[:pq]
        # Ignore filters with no data.
        search_filters[:pq].reject{|q_id, ans| ans.blank? }.each do |ques_id, text|
          custom_profile_filters[ques_id] = text
        end
      end
      return custom_profile_filters
    end

    # Filters records in <i>@users</i> by the profile field filters in
    # <i>params[:search_filters][:question]</i>
    def apply_profile_filters!(program, user_ids, filter_questions, custom_profile_filters, my_filters)
      q_ids = custom_profile_filters.keys
      question_by_id = {}
      filter_questions.select{|q| q_ids.include?(q.id.to_s)}.each do |question|
        question_by_id[question.id] = question
      end

      custom_profile_filters.each do |question_id, answer_data|
        question_obj = question_by_id[question_id.to_i]
        my_filters << {:label => question_obj.question_text, :reset_suffix => "profile_question_#{question_obj.id}"} unless my_filters.nil?
        filter_based_on_question_type!(program, user_ids, question_obj, answer_data)
      end
    end

    def get_locations_ids(value)
      location_ids = [0]
      value.split(AdminView::LOCATION_VALUES_SPLITTER).each do |location|
        tmp_ary = location.split(AdminView::LOCATION_SCOPE_SPLITTER)
        where_query = {}
        where_query[:city] = tmp_ary[-3] if tmp_ary[-3]
        where_query[:state] = tmp_ary[-2] if tmp_ary[-2]
        where_query[:country] = tmp_ary[-1] if tmp_ary[-1]
        location_ids << Location.where(where_query).pluck(:id) if where_query.present?
      end
      location_ids.flatten
    end

    # Filter the <i>users</i> collection based on whether the the answers for the
    # <i>question</i> matches <i>answer_data</i>
    def filter_based_on_question_type!(program, user_or_member_ids, question, answer_data, options = {})
      return if user_or_member_ids.blank?
      select_cond, user_program_cond = get_query_conditions(program, options[:filter_for_members])
      if question.email_type?
        formatted_answer_data = answer_data.strip.format_for_mysql_query(delimit_with_percent: true)
        query = "#{select_cond} WHERE M.email LIKE #{formatted_answer_data}"
      elsif question.location?
        query = "#{select_cond}
          join profile_answers A on A.ref_obj_id = M.id
          WHERE A.location_id IN (#{UserProfileFilterService.get_locations_ids([answer_data].flatten.join(',')).join(',')})
          AND A.profile_question_id = #{question.id}
          #{user_program_cond}
          AND A.ref_obj_type='#{Member.name}'"
      elsif question.choice_or_select_type?
        query = "#{select_cond}
            join profile_answers A on A.ref_obj_id = M.id
            AND A.profile_question_id = #{question.id}
            #{user_program_cond}
            AND A.ref_obj_type='#{Member.name}'
            join answer_choices AC on AC.ref_obj_id = A.id
            AND AC.ref_obj_type='#{ProfileAnswer.name}'
            AND AC.question_choice_id IN (#{Array(answer_data).join(',')})"
      elsif question.date?
        query = get_date_query(answer_data, query_prefix: "#{select_cond} #{profile_question_answer_join_query(ActiveRecord::Base.connection.quote('Member'), members: 'M')}", join_date_answers: true, profile_question: question, query_suffix: user_program_cond)
      else
        # For the input answer_data: ['a', 'c']
        # Constructing the query: WHERE answer_text LIKE '%a%' AND answer_text LIKE '%c%'

        if options[:perform_in_operation]
          ans = "A.answer_text in (?)"
          ans = ActiveRecord::Base.send :sanitize_sql_array, [ans, answer_data]
        else
          ans = answer_data.split(/\s+/)
          ans = ans.collect{|data| data.format_for_mysql_query(delimit_with_percent: true) }
          ans = ans.collect{|data| "A.answer_text LIKE #{data}"}.join(' AND ')
        end



        query = "#{select_cond}
           join profile_answers A on A.ref_obj_id = M.id
           WHERE #{ans}
           AND A.profile_question_id = #{question.id}
           #{user_program_cond}
           AND A.ref_obj_type='#{Member.name}'"
      end
      answered_user_ids = ActiveRecord::Base.connection.select_values(query)
      user_or_member_ids.replace(user_or_member_ids & answered_user_ids)
    end

    def filter_based_on_regex_match(program, user_or_member_ids, question, answer_data, options = {})
      return if user_or_member_ids.blank?
      select_cond, user_program_cond = get_query_conditions(program, options[:filter_for_members])
      choices, separator = get_choices_for_pattern_match(question, answer_data)
      regex_cond =  if question.choice_based?
                      "CONCAT('#{separator} ', concat(A.answer_text, '#{separator}')) REGEXP #{choices}"
                    elsif question.ordered_options_type?
                      "CONCAT('#{separator} ', concat(A.answer_text, ' #{separator}')) REGEXP #{choices}"
                    end
      query = "#{select_cond}
          join profile_answers A on A.ref_obj_id = M.id
          WHERE #{regex_cond}
          AND A.profile_question_id = #{question.id}
          #{user_program_cond}
          AND A.ref_obj_type='#{Member.name}'"
      answered_user_ids = ActiveRecord::Base.connection.select_values(query)
      user_or_member_ids & answered_user_ids
    end

    def add_location_parameters_to_options(search_filters_param, options, my_filters, geo_field_name = nil)
      # Apply location search
      pivot_location = true

      if search_filters_param.present? && search_filters_param[:location]
        ques_id = search_filters_param[:location].keys.first
        question_obj = ProfileQuestion.find(ques_id)
        loc_filter = search_filters_param[:location][ques_id]
        if loc_filter && loc_filter[:name].present?
          my_filters << { label: question_obj.question_text, reset_suffix: "profile_question_#{ques_id}" } unless my_filters.nil?
          # Find the reliable location with lat and lng having the given full address.
          unless is_typed_location_free_text?(loc_filter[:name])
            create_location_filter(options, loc_filter[:name])
          else
            begin
              create_location_filter_for_free_text_from_google_geocode(options, loc_filter[:name], geo_field_name)
            rescue Geokit::Geocoders::GeocodeError
              options.delete(:geo)
              pivot_location = false
            end
          end
        end
      end
      return { options: options, pivot_location: pivot_location, my_filters: my_filters }
    end

    def add_location_parameters_based_on_google_geocode(options)
      create_location_filter(options, options[:geo][:location_name])
      options.delete(:geo)
      options
    end
  end

  private

  def initialize_filterable_and_summary_questions
    role_questions = @current_program.role_profile_questions_excluding_name_type(@roles, @current_user)
    @filter_questions = role_questions.select(&:filterable).collect(&:profile_question).uniq
    @in_summary_questions = role_questions.select(&:show_in_summary?)
    @profile_questions = @in_summary_questions.collect(&:profile_question).uniq
    @profile_filterable_questions = ProfileQuestion.sort_listing_page_filters(@profile_questions & @filter_questions)
    @non_profile_filterable_questions = ProfileQuestion.sort_listing_page_filters(@filter_questions - @profile_filterable_questions)
  end

  def self.get_query_conditions(program, filter_members = false)
    if filter_members.present?
      ["SELECT DISTINCT M.id FROM members M", ""]
    else
      ["SELECT DISTINCT U.id FROM users U join members M on U.member_id = M.id",
      "AND U.program_id = #{program.id}"]
    end
  end

  def self.get_choices_for_pattern_match(question, answer_data)
    if question.choice_based?
      separator = ProfileAnswer::SEPERATOR.strip
      r_separator = Regexp.escape(separator)
      # For the input answer_data: ['a', 'c']
      # Constructing the query: WHERE ",a,b,c," REGEXP ",a,|,c,"
      # => by transforming "answer_text" -> ",answer_text,"
      # => and answer_data from ['a', 'c'] -> ",a,|,c,"
      ans = answer_data.collect{|data| Regexp.escape(data)}
      ans = ans.join("#{r_separator}|#{r_separator} ")
      ans = "#{r_separator} #{ans}#{r_separator}"
      ans = User.connection.quote(ans)
    else
      separator = ProfileAnswer::DELIMITOR.strip
      r_separator = Regexp.escape(separator)
      # For the input answer_data: ['a', 'c']
      # Constructing the query: WHERE "| a | b | c |" REGEXP "\| a \||\| c \|"
      # => by transforming "answer_text" -> "| answer_text |"
      # => and answer_data from ['a', 'c'] -> "\| a \||\| c \|"
      ans = answer_data.collect{|data| Regexp.escape(data)}
      ans = ans.join(" #{r_separator}|#{r_separator} ")
      ans = "#{r_separator} #{ans} #{r_separator}"
      ans = User.connection.quote(ans)
    end
    [ans, separator]
  end

  def self.is_typed_location_free_text?(location_name)
    full_location_array = location_name.split(Location::FULL_LOCATION_SPLITTER).map(&:strip)
    return true if full_location_array.size > 3
    where_query = {}
    where_query[:city] = full_location_array[-3] if full_location_array[-3]
    where_query[:state] = full_location_array[-2] if full_location_array[-2]
    where_query[:country] = full_location_array[-1] if full_location_array[-1]
    !Location.exists?(where_query)
  end

  def self.create_location_filter(options, location_name)
    options[:location_filter] = {}
    options[:location_filter][:address] = location_name
    options[:location_filter][:field] = "member.location_answer.location.full_location"
  end

  def self.create_location_filter_for_free_text_from_google_geocode(options, location_name, geo_field_name)
    google_provided_location = Location.geocode(location_name)
    options[:geo] = {point: [google_provided_location.lng, google_provided_location.lat]}
    options[:geo][:location_name] = [google_provided_location.city, google_provided_location.state_name, CountryCodes.find_by_a2(google_provided_location.country_code)[:name]].join(Location::FULL_LOCATION_SPLITTER)
    options[:geo][:field] = geo_field_name || "location_answer.location.point"
    options[:geo][:distance] = Location::LocationFilter::DEFAULT_RADIUS
  end
end