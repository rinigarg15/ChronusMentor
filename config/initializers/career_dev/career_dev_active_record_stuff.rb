module ActiveRecord
  module Associations
    module ClassMethods
      def belongs_to_portal(opts = {})
        assoc_opts =  {:class_name => 'CareerDev::Portal',
                       :foreign_key => 'program_id'
                      }.merge(opts)

        belongs_to  :portal, assoc_opts
      end
    end
  end
end