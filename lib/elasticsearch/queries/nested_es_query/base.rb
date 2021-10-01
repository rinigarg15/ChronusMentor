class NestedEsQuery::Base

  attr_accessor :start_date_id, :end_date_id, :filterable_ids

  # filterable_ids: Contracting space for search implemented for optimisation
  def initialize(program, start_time, end_time, options = {})
    self.start_date_id = start_time.utc.to_i / 1.day.to_i
    self.end_date_id = end_time.utc.to_i / 1.day.to_i
    if self.filterable_ids.nil?
      self.filterable_ids = options[:ids].nil? ? program.all_user_ids : options[:ids]
    end
  end

  def get_filtered_ids
    filtered_ids = get_hits
    self.filterable_ids -= filtered_ids

    if self.filterable_ids.present?
      positive_inner_hits_map = get_inner_hits_map(true)
      if positive_inner_hits_map.present?
        self.filterable_ids = positive_inner_hits_map.keys
        filtered_ids += cumulate_and_filter_positive_inner_hits(positive_inner_hits_map, get_inner_hits_map(false))
      end
    end
    filtered_ids.uniq
  end

  private

  def cumulate_inner_hits_maps(map_1, map_2, operation = :difference)
    (map_1.keys + map_2.keys).uniq.inject({}) do |cumulative_map, k|
      map_2_value = map_2[k].to_i
      map_2_value = -map_2_value if operation == :difference

      cumulative_map[k] = map_1[k].to_i + map_2_value
      cumulative_map
    end
  end

  def filter_positive_inner_hits(map)
    map.select { |_, v| v > 0 }.keys
  end

  def cumulate_and_filter_positive_inner_hits(map_1, map_2, operation = :difference)
    filter_positive_inner_hits(cumulate_inner_hits_maps(map_1, map_2, operation))
  end
end