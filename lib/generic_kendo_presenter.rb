class GenericKendoPresenter
  def initialize(model, config = {}, params = {})
    @model  = model
    @params = params
    @config = config

    check_default_scope_key #not checking for the value as it would enumerate the scope
    store_posts_to_attributes_hash
  end

  def list
    scopes = build_all_scopes
    scopes.nil? ? @model.all : scopes
  end

  # This can be DRYed a bit more, using alias_chaining or whatever!
  def total_count
    scope = default_scope
    scope = scope.merge(build_filter_scopes(@params[:filter][:filters])) unless no_filters_present?
    scope.count
  end

  def filtered_scope
    scope = default_scope
    scope = scope.merge(build_filter_scopes(@params[:filter][:filters])) unless no_filters_present?
    return scope
  end

  private

  def no_sort_options_present?
    @params[:sort].blank?
  end

  def no_filters_present?
    @params[:filter].blank? || @params[:filter] == "null"
  end

  def no_pagination_options_present?
     @params[:take].blank? || @params[:skip].blank?
  end

  def is_valid_filter?(field)
    !@posts_to_attrs_hash[field].blank?
  end

  def self.convert_kendo_date_to_datetime_in_user_timezone(date_str, operator)
    # Date.beginning_of_day & Date.end_of_day converts Date to Time in Time.zone(i.e user's time zone)
    date = Date.strptime(date_str, '%m/%d/%Y')
    time_of_the_day =
      case operator
      when "lte"
        :end_of_day
      when "gte"
        :beginning_of_day
      end
    date.send(time_of_the_day)
  end

  def default_scope
    # pass the model name as well - otherwise it throws exceptions on joins(sometime )
    @config[:default_scope]
  end

  def self.has_custom_filtering?(attr_config)
    attr_config.has_key?(:custom_filter)
  end

  def self.has_custom_sorting?(attr_config)
    attr_config.has_key?(:custom_sort)
  end

  def self.custom_filter_scope(attr_config, filter)
    attr_config[:custom_filter].call(filter)
  end

  def self.custom_sort_scope(attr_config, direction)
    attr_config[:custom_sort].call(direction)
  end

  def check_default_scope_key
    raise "Default Scope should be set" unless @config.has_key?(:default_scope)
  end  

  def self.is_nested_filter?(filter)
    filter.has_key?(:filters)
  end

  # # Looks like we can scope on different models as well, but it is not included here
  # http://makandracards.com/makandra/1266-merge-two-arbitrary-scopes-in-rails-3
  # http://blog.thefrontiergroup.com.au/2011/03/composing-scopes-on-multiple-models-with-rails-3/
  def merge_scopes(scopes)
    scopes.inject(default_scope) { |mem, var| mem.merge(var) }
  end

  def build_pagination_scopes
    default_scope.offset(@params[:skip]).limit(@params[:take])
  end

  # Sort is supported only for attributes
  def build_sort_scopes
    field = @params[:sort]["0"][:field]
    order = @params[:sort]["0"][:dir]
    attribute = @posts_to_attrs_hash[field]
    return default_scope if attribute.nil?

    attributes_config = @config[:attributes][attribute]
    return self.class.custom_sort_scope(attributes_config,order) if self.class.has_custom_sorting?(attributes_config)

    default_scope.order("#{attribute} #{order}")
  end

  def store_posts_to_attributes_hash
    return {} if @config[:attributes].nil?
    filterable_attrs_hash = @config[:attributes].keep_if {|attribute, attr_hash| attr_hash[:filterable]}
    val = filterable_attrs_hash.collect do |attribute, attr_hash|
      [attr_hash[:posted_as] || attribute.to_s, attribute]
    end
    @posts_to_attrs_hash = Hash[val]
  end

  # Given a kendo scope, this will return filtered output.
  # Only strings and datetime formats are supported. We shoudl be able to easily extend it

  def build_simple_scope(filter)
    field = filter[:field]
    operator = filter[:operator]
    value = filter[:value]
    return default_scope unless is_valid_filter?(field) and !value.blank?
    attribute = @posts_to_attrs_hash[field]
    attributes_config = @config[:attributes][attribute]

    return self.class.custom_filter_scope(attributes_config,filter) if self.class.has_custom_filtering?(attributes_config)

    case attributes_config[:type]
    when :string
      @model.where("#{@model.table_name}.#{attribute} LIKE ?", "%#{value}%")
    when :datetime
      time = self.class.convert_kendo_date_to_datetime_in_user_timezone(value, operator)
      # Support only lte & gte as of now. In case of kendo clear filter, it is setting the operations back to lt or gt
      case operator
      when "lte"
        @model.where("#{@model.table_name}.#{attribute} <= ?", time)
      when "gte"
        @model.where("#{@model.table_name}.#{attribute} >= ?", time)
      end
    end
  end


  # Logic is always 'AND' in between scopes
  def build_filter_scopes(filter_params)
    scopes = []
    cnt = 0
    filter_params.each do |indx, filter|
      scopes[cnt] = self.class.is_nested_filter?(filter) ? build_filter_scopes(filter[:filters]) : build_simple_scope(filter)
      cnt += 1
    end
    merge_scopes(scopes)
  end
  
  def build_all_scopes
    scope = default_scope
    scope = scope.merge(build_filter_scopes(@params[:filter][:filters])) unless no_filters_present?
    scope = scope.merge(build_pagination_scopes) unless no_pagination_options_present?
    scope = scope.merge(build_sort_scopes) unless no_sort_options_present?
    return scope
  end


end