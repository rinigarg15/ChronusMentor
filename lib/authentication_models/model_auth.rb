# This is the abstract class
class ModelAuth

  module ValidationOperators
    EQUALS = "eq"
    REGEX_MATCH = "regex"
  end

  class NotImplementedError < RuntimeError; end

  def self.authenticate?(auth_obj, options)
    raise NotImplementedError, "Not implemented"
  end

  private

  def self.imported_data(options, response_attributes)
    imported_data = Marshal.load(Marshal.dump(options["import_data"]["attributes"]))
    imported_data.each do |model, attr|
      attr.each do |column, identifier|
        attr[column] = response_attributes[identifier]
      end
    end
  end

  def self.validate_attributes_from_sso(auth_obj, options, response_attributes)
    if options["validate"].present?
      auth_obj.has_data_validation = true
      validation_criteria = Marshal.load(Marshal.dump(options["validate"]["criterias"]))
      auth_obj.is_data_valid = validation_criteria.any? { |list| validate_criteria?(list, response_attributes) }
      auth_obj.permission_denied_message = options["validate"]["fail_message"]
      auth_obj.prioritize_validation = options["validate"]["prioritize"]
    end
  end

  def self.validate_criteria?(list, response_attributes)
    list["criteria"].all? do |criterion|
      attribute = response_attributes[criterion["attribute"]].to_s
      if criterion["attribute"].present? && criterion["operator"].present? && criterion["value"].present? && attribute.present?
        case criterion["operator"]
        when ValidationOperators::EQUALS
          attribute.downcase == criterion["value"].downcase
        when ValidationOperators::REGEX_MATCH
          attribute.match(criterion["value"]).present?
        else
          false
        end
      end
    end
  end
end