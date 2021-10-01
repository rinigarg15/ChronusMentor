# In some places we use 'request.path' , 'request.full_path' which will return /users instead of /p/<program_root>/users.
# To fix this, we have written the following patch!
ActionDispatch::Request.class_eval do
  def path
    _path = super
    prefix_current_root(_path)
  end

  def fullpath
    _path = super
    prefix_current_root(_path)
  end

  def prefix_current_root(_path)
    if env['CURRENT_PROGRAM_ROOT'].present? && _path !~ %r(^/#{SubProgram::PROGRAM_PREFIX}([^/]+))
        "/#{SubProgram::PROGRAM_PREFIX}#{env['CURRENT_PROGRAM_ROOT']}#{_path}"
    else
      _path
    end
  end
end

ActionController::Base.class_eval do
  # Serializes the record into the session, under the key of the current model
  # name
  #
  def serialize_to_session(record)
    return unless record
    error_info = {}

    # Make a <attr => error messages> hash out of the record errors.
    # There is no <i>to_hash</i> method for activerecord errors.
    record.errors.each do |attr, msg|
      error_info[attr] = msg
    end

    flash[:active_object] ||= {}
    flash[:active_object].merge!(record.class.name => {
        :attributes => record.attributes,
        :errors => error_info})
    flash.instance_variable_get(:@discard).delete(:active_object)
  end

  # Get record from the session for this model name to assign the hash to
  # current object
  #
  # FIXME Any better way of assigning all attributes, associations, etc., from a
  # record to another record?
  #
  def deserialize_from_session(record_class, default_object = nil, *protected_attrs)
    record_obj = default_object

    # If there is no object stored in the session, return the default object or
    # create a new one
    #
    if flash[:active_object] && flash[:active_object][record_class.name]
      record_info = flash[:active_object][record_class.name]
      record_obj ||= record_class.find_by(id: record_info[:attributes]['id'])
      record_obj ||= record_class.new

      # Can't mass assign protected attributes. Hence do a manual assignment of
      # protected attributes
      protected_attrs.each do |attr|
        record_obj.send("#{attr}=", record_info[:attributes].delete(attr.to_s))
      end

      # Assign attributes and errors from the stored object
      record_obj.attributes = record_info[:attributes]

      (record_info[:errors] || {}).each_pair do |field, error|
        record_obj.errors.add(field, error)
      end
    end

    return record_obj || record_class.new
  end

  helper_method :serialize_to_session, :deserialize_from_session
end

ActionMailer::Base.class_eval do # Rails3L
  def params
    {}
  end
end

# https://github.com/svenfuchs/routing-filter/issues/47
ActionDispatch::Routing::RouteSet::NamedRouteCollection::UrlHelper.class_eval do
  def self.optimize_helper?(route)
    false
  end
end

ActionController::Parameters.class_eval do
  def to_h
    if permitted?
      convert_parameters_to_hashes(@parameters, :to_h)
    elsif Rails.env.development? || Rails.env.test?
      raise ActionController::UnfilteredParameters
    else
      Airbrake.notify("UnpermittedParameters! Please Fix.")
      self.to_unsafe_h
    end
  end
end