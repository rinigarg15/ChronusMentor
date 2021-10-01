module Elasticsearch
  module Model
    module Response
      module Pagination
        module WillPaginate
          def per_page(num = nil)
            if num.nil?
              search.definition[:body][:size]
            else
              paginate(page: current_page, per_page: num) # shorthand
            end
          end

          def length
            search.definition[:body][:size]
          end

          def paginate(options)
            param_name = options[:param_name] || :page
            page       = [options[param_name].to_i, 1].max
            per_page   = (options[:per_page] || __default_per_page).to_i

            search.definition[:body].update size: per_page,
                                     from: (page - 1) * per_page
            self
          end

          def current_page
            search.definition[:body][:from] / per_page + 1 if search.definition[:body][:from] && per_page
          end
        end
      end
    end

    module Naming

      module ClassMethods

        private
        # Below patch can be removed once the PR(https://github.com/elastic/elasticsearch-rails/pull/717) is merged to elasticsearch master branch.
        def implicit(prop)
          value = nil

          if Elasticsearch::Model.settings[:inheritance_enabled]
            self.ancestors.each do |klass|
              next if klass == self || self.respond_to?(:target) && klass == self.target
              break if value = klass.respond_to?(prop) && klass.send(prop)
            end
          end

          value || self.send("default_#{prop}")
        end
      end
    end

  end
end
