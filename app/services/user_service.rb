class UserService

  module AddMemberFromProgram
    ColumnSort = {
      'first_name' => "name_only.sort",
      'last_name' => "last_name.sort",
      'email' => "email.sort"
    }

    EsOptions = {
      items_per_page: 25,
      sort_param: 'first_name',
      sort_order: 'asc'
    }
  end

  def self.get_es_search_hash(current_program, current_organization, options)
    search_hash = {
      per_page: options[:items_per_page],
      page: options[:page],
      sort_field: AddMemberFromProgram::ColumnSort[options[:sort][:column]],
      sort_order: options[:sort][:order]
    }

    with_options = { organization_id: current_organization.id }
    without_options = {state: Member::Status::SUSPENDED, "users.program_id": current_program.id}
    if options[:filters][:program_id].present?
      with_options[:"users.program_id"] = options[:filters][:program_id]
    end

    role_filter = options[:filters][:role]
    with_options = handle_role_filter(role_filter, with_options) if role_filter.present?

    search_hash[:with] = with_options
    search_hash[:without] = without_options
    search_hash
  end

  def self.get_listing_options(params = {})
    options = {sort: {}, filters: {}}

    options[:items_per_page] = params[:items_per_page] || AddMemberFromProgram::EsOptions[:items_per_page]
    options[:page] = params[:page] || 1

    options[:sort][:column] = params[:sort_param] || AddMemberFromProgram::EsOptions[:sort_param]
    options[:sort][:order] = params[:sort_order] || AddMemberFromProgram::EsOptions[:sort_order]

    options[:filters][:search] = params[:search_content]
    options[:filters][:role] = params[:filter_role]
    options[:filters][:program_id] = handle_program_id_filter(params[:filter_program_id])
    if params[:filter_program_id].present? && params[:filter_role].present? && params[:filter_role] == MembersHelper.state_to_string_map[Member::Status::DORMANT]
      options[:filters][:role] = ""
    end

    options
  end


  private
  def self.handle_program_id_filter(program_id_filter = nil)
    return if program_id_filter.blank?
    program_id_filter.is_a?(Array) ? program_id_filter.map(&:to_i) : program_id_filter.to_i
  end

  def self.handle_role_filter(role_filter, with_options)
    if role_filter.include?(MembersHelper.state_to_string_map[Member::Status::DORMANT])
      with_options[:state] = Member::Status::DORMANT
      with_options.delete("users.program_id")
    else
      with_options[:"users.role_references.role_id"] = role_filter.map(&:to_i)
    end
    return with_options
  end
end
