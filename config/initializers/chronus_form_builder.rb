#
# Custom FormBuilder with support for showing inline field validation errors
# close to related fields.
#

class ActionView::Helpers::FormBuilder
  include FormErrorHelper
  # The error_message helper is removed from rails 3(hence copied the code from rails 2.x)
  def error_messages(options = {})
    @template.error_messages_for(@object_name, objectify_options(options))
  end
end

module ActionViewHelpersTagsBaseDefaultOverrides
  # It seems when the field value is nill rails internally does field.to_s.
  # This seems to be a problem when we use something like this:
  # => f.select :year, ['2005', '2004', nil]
  # If the year is nil, instead of selecting the last option, it will still select the first options(here 2005)
  def options_for_select(container, selected = nil)
    selected[:selected] ||= '' if selected
    super
  end
end

ActionView::Helpers::Tags::Base.prepend(ActionViewHelpersTagsBaseDefaultOverrides)

class ActiveRecord::Base
  # Constructs and returns Hash of error messages mapped to model attribute
  # names, suitable for displaying as form validation errors.
  #
  def field_error_messages
    record_errors = Hash.new

    # Construct map from each field name to corresponding human readable error
    # message.
    self.errors.each do |attr, error_msg|
      #
      # Replace _'s with ' 's (spaces) in field names so that the error message
      # for a field like email_confirmation says 'Email confirmation ....'
      #
      field_error_msg = self.class.human_attribute_name(attr) + ' ' + error_msg
      record_errors[attr.to_sym] = field_error_msg
    end

    return record_errors
  end
end
