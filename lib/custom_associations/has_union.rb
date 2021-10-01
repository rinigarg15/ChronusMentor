module CustomAssociations
  module HasUnion
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      #
      # has_union simply presents a union'ed view of one or more ActiveRecord
      # relationships (has_many or has_and_belongs_to_many, acts_as_network, etc).
      #
      #   class Person < ActiveRecord::Base
      #     has_many  :old_books
      #     has_many  :new_books
      #     has_union :books,
      #               :class_name => 'Book',
      #               :collections => [:old_books, :new_books]
      #   end
      #
      def has_union(association_id, options = {})
        class_eval do
          # Scope to the type of records this has_union returns, given by
          # options[:class_name]
          proxy_scope = options.delete(:class_name).constantize
          collections = options.delete(:collections)

          # Define the association method
          define_method(association_id) do |*opts|
            arg_options = opts.extract_options!
            #
            # Fetch each of the collections by evaluating the given expression.
            # Note that doing self.send(m) will not work for us since the
            # collection can be either a direct association like branch or
            # cascaded like tree.branches, where the latter won't work with
            # Object#send.
            #
            aggregated_collection = assoc_accessors(collections).collect do |access_str|
              eval(access_str.to_s)
            end.flatten.compact.uniq

            return aggregated_collection if arg_options[:without_scope]

            # Return a new scope with proxy_options restricting to the
            # records in the aggregated_collection.
            # http://stackoverflow.com/questions/18198963/with-rails-4-model-scoped-is-deprecated-but-model-all-cant-replace-it
            proxy_scope.where(options.except(:order).merge({:id => aggregated_collection})).order(options[:order])
          end

          private

          # Takes the assocation options of the following form and returns an
          # Array of strings, where each string when evaluated gives the
          # association's value.
          #
          #   [:leaves, {:branches => :new_leaves}, {:garden => :fallen_leaves}]
          #
          # There are 3 kinds of values that the options hash can contain.
          #   1. Direct association on the record
          #   2. Association on a singular association of the record.
          #   3. Association on a plural association of the record.
          #
          # Following are the ways in which the eval string is computed for
          # each of option entries.
          #   1. :leaves                      #=> self.leaves
          #   2. {:garden => :fallen_leaves}  #=> self.garden.leaves
          #   3. {:branches => :new_leaves}   #=> self.branches.collect(&:leaves).flatten
          #
          def assoc_accessors(assoc_opts)
            assoc_opts = [assoc_opts] unless assoc_opts.is_a?(Array)

            eval_str_arr = []

            assoc_opts.each do |item|
              case item
              when String, Symbol
                # Push the association directly into the output array.
                eval_str_arr << item
              when Hash
                # For each pair, construct a string that will call the
                # association given by the key, and on each record thus
                # returned, calls the assocation given by the value. Push all
                # these strings into the output array.
                item.each do |key, value|
                  value = { :collect => value, :options => {} } if (value.is_a?(String) || value.is_a?(Symbol))
                  # Hash need to be of the form
                  # {:collect => :assoc, :options =>{:include => :assoc} }
                  eval_str_arr << get_eval_str(key, value)
                end
              end
            end

            eval_str_arr
          end

          def get_eval_str(key, value)
            "[#{key}.where(#{value[:options]})].compact.flatten.collect(&:#{value[:collect]}).flatten"
          end
        end
      end
    end
  end
end