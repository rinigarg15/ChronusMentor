module SalesDemo
  module PopulatorUtils
    def assign_data(object, ref_object)
      self.class::REQUIRED_FIELDS.each do |field|
        object.send("#{field}=", ref_object.send(field))
      end
      self.class::MODIFIABLE_DATE_FIELDS.each do |field|
        object.send("#{field}=", modify_date(object.send(field)))
      end
    end

    def convert_to_objects(contents)
      contents.collect do |content|
        OpenStruct.new(content)
      end
    end

    def filter_and_convert_to_objects(contents, filter_key, filter_val)
      contents.collect do |content|
        next unless content[filter_key]
        next unless content[filter_key] == filter_val
        OpenStruct.new(content)
      end.compact
    end

    def modify_date(source_date, conversion_method = "to_time", delta_method = "delta_date")
      return if source_date.blank?

      source_date.send(conversion_method) + self.master_populator.send(delta_method)
    end

    def modify_hash(yaml, from = :from, to = :to)
      hash = YAML.load(yaml)
      hash[:role][from] = get_role_ids(hash[:role][from]) if hash[:role][from].present?
      hash[:role][to] = get_role_ids(hash[:role][to]) if hash[:role][to].present?
      return hash
    end

    def get_role_ids(ids)
      return ids.collect{|id| self.master_populator.solution_pack_referer_hash["Role"][id.to_i]}
    end
  end
end