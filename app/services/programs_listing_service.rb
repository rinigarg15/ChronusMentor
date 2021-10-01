class ProgramsListingService
  # @Params
  # scope: controller variable to set instance variable
  # base: object, with respect to which we need to fetch programs
  # condition_object: object, with respect to which show condition need to be evaluated. Default is the organization of the base
  # options: Pass options to override default settings of ProgramTypeConstants
  # block: block to perform scoping 
  def self.fetch_programs(scope, base, condition_object = nil, options = {}, &block)
    program_type_count = 0
    programs_view_count = 0
    condition_object ||= base.is_a?(Organization) ? base : base.organization
    program_type_constants = get_merged_hash(Program::ProgramTypeConstants::ProgramsType, options)
    program_type_constants.each do |program_type, program_constant|
      program_constant[:show_condition]
      can_show = program_constant[:show_condition] == true || condition_object.public_send(program_constant[:show_condition].to_sym)
      if can_show
        programs = yield(base.public_send(program_constant[:association].to_sym))
        scope.instance_variable_set("@#{program_constant[:instance_name]}", programs)
        program_type_count+=1 if programs.present?
        programs_view_count += programs.size
      else
        scope.instance_variable_set("@#{program_constant[:instance_name]}", nil)
      end
    end
    scope.instance_variable_set("@programs_view_count", programs_view_count)
    scope.instance_variable_set("@program_types_count", program_type_count)
  end

  # @Params
  # scope = view object to get instance variable
  # wrapper_proc = Styling block in case of multiple program type listing
  # options = 1. Pass options to override default settings of ProgramTypeConstants
  #           2. Divider Styling as :divider key
  def self.list_programs(scope, wrapper_proc, options = {}, &block)
    program_type_constants = get_merged_hash(Program::ProgramTypeConstants::ProgramsType, options)
    program_types = program_type_constants.sort_by{|key, hash| hash[:order]}
    program_types_count = scope.instance_variable_get("@program_types_count")
    result = ""
    current_types_count = 0
    program_types.each do |program_type, program_constant|
      programs = scope.instance_variable_get("@#{program_constant[:instance_name]}")
      if programs.present?
        programs_term = programs.size > 1 ? scope._Programs : scope._Program
        options[:title] = program_constant[:title_key].translate(Programs: programs_term, Career_Development: scope._Career_Development) if program_constant[:title_key].present?

        if wrapper_proc.present? && (program_types_count > 1 || options[:enforce_wrapper])
          result << wrapper_proc.call(programs, options, &block)
        else
          result << yield(programs, options)
        end
        result << options[:divider] if ((current_types_count +=1) != program_types_count) && options[:divider].present?
      end
    end
    return result.html_safe
  end

  def self.get_merged_hash(hash, options)
    return hash if (hash.keys & options.keys).empty?
    new_hash = hash.deep_dup
    new_hash.each do |key, sub_hash|
      new_hash[key].merge!(options[key] || {})
    end
  end

  def self.get_applicable_programs(organization, options = {})
    return [] if organization.standalone?
    programs = []
    program_type_constants = get_merged_hash(Program::ProgramTypeConstants::ProgramsType, options)
    program_types = program_type_constants.sort_by{|key, hash| hash[:order]}
    program_types.each do |program_type, program_constant|
      can_show = program_constant[:show_condition] == true || organization.public_send(program_constant[:show_condition].to_sym)
      programs += organization.public_send(program_constant[:association].to_sym).ordered if can_show
    end
    return programs
  end
end
