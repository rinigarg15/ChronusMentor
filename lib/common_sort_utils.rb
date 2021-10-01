module CommonSortUtils
  ID_SORT_FIELD = 'id'
  SORT_ASC = 'asc'
  SORT_DESC = 'desc'

  class << self
    def fill_user_sort_input_or_defaults!(hsh, params_in = nil, options = {})
      params_in = hsh if params_in.nil?
      local_abstractor = ->(allowed_values_method, key, params_in, options, default_value) { CommonSortUtils.send(allowed_values_method).include?(params_in[key].presence) ? params_in[key].presence : (options[:"default_#{key}"] || default_value) }
      hsh[:sort_field] = local_abstractor[:allowed_sort_fields, :sort_field, params_in, options, ID_SORT_FIELD]
      hsh[:sort_order] = local_abstractor[:allowed_sort_orders, :sort_order, params_in, options, SORT_DESC]
      hsh
    end

    private

    def allowed_sort_fields
      [ID_SORT_FIELD]
    end

    def allowed_sort_orders
      [SORT_ASC, SORT_DESC]
    end
  end
end