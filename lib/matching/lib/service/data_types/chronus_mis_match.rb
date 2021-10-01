module Matching

  class ChronusMisMatch < AbstractType
    # store is used to store member_id in mentor documents and managers_array in student documents
    attr_accessor :store

    def initialize(value)
      self.store =  value
    end

    def value
      self.store
    end
    
    def no_data?
      self.store.nil?
    end

    def self.get_marshalled_data(instance)
      instance.store
    end

    def self.create_object_from_marshalled_data(mongo_instance)
      ChronusMisMatch.new(mongo_instance)  
    end

    def do_match(other_field, options = {})
      !self.store.include?(other_field.store)
    end

  end
end