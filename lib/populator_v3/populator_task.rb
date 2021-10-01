require "faker"
require "populator"
require_relative './../tasks/populator/data_populator'
require_relative './../tasks/populator/performance_populator'

class PopulatorTask < DataPopulator

  include PopulatorTaskUtils

  def initialize(node, options = {})
    @options = options
    @node_populator_class = (options[:populator_class] || (node.camelize + "Populator")).constantize
    @node = node
    @parent = options[:args].try(:[], "parent") || options[:parent]
    @foreign_key = "#{(options[:args].try(:[], "parent_key") || @parent)}_id"
    @counts_ary = options[:counts_ary] || (raise "Counts array not present")
    @percents_ary = options[:percents_ary] || (raise "Percents array not present")
    @type = options[:type]
    @organization = options[:organization]
    @program = options[:program]
    @add_item_callback = "add_#{node}".pluralize.to_sym
    @remove_item_callback = "remove_#{node}".pluralize.to_sym
    @display = options[:display]

    @translation_locales = options.try(:[], :common).try(:[], "translation_locales") || []
    @translation_locales << I18n.default_locale.to_s
    @translation_locales.uniq!
  end

  def patch
    raise "PopulatorTask patch() is getting called"
  end

  # class methods
  class << self
    def benchmark_wrapper(name)
      if Rails.env.test?
        yield
      else
        newline
        start_time = Time.now
        print_and_flush "Starting #{name}"
        yield
        end_time = Time.now
        time_diff = end_time - start_time
        newline
        print_and_flush "Completed #{name} in #{formatted_populator_time_display(time_diff)}"
        newline
      end
    end

    def display_populated_count(count, object)
      super unless Rails.env.test?
    end

    def display_deleted_count(count, object)
      super unless Rails.env.test?
    end

    def newline
      super unless Rails.env.test?
    end

    def dot
      super unless Rails.env.test?
    end
  end

  def dot
    @display ? @display.dot : self.class.dot
  end

  #==================================================================================================================================
  # Given: parent model, child model, percent array(parent), count array(child)
  # Function process_patch takes parent model and child model and classify parents based on their children count and  put them in buckets.
  # For Ex. Parent is Member, Child is Article, members [1,2,3,4,5] has 1 article and members [6,7,8,9,10] has 3 articles
  # Our buckets will be {count: 1, parent_ids: [1,2,3,4,5]} and {count: 3, parent_ids: [6,7,8,9,10]} 
  # For Bucket: {count: 1, parent_ids: [1,2,3,4,5]} we define bucket_count = count i.e 1 and bucket_parents_size = parent_ids.size i.e 5 
  # If x belongs to parent_ids of a bucket then x is called member of that bucket for example 2 is member of bucket {count: 1, parent_ids: [1,2,3,4,5]}
  # function add_remove_record takes parent array(Member), bucket, percent([70, 30]) and child count array ([2, 1]) 
  # function get_parents_count_ary splits parents based on percent array so parents_count_ary is [7, 3] in this example
  # now we loop thorugh child count array say current child count is 2
  # we call update bucket function
  # we say bucket with count 2 as target bucket and 2 as target count
  # we check in the buckets if bucket with count 2 is present?
  #  if yes
  #     we compare bucket_parents_size with  parents_count(7 in this example)
  #     if bucket_parents_size == parents_count do nothing
  #     if bucket_parents_size < parents_count 
  #       we look for bucket with count > target_count we say it current_bucket and take (parents_count - bucket_parents_size) members from bucket
  #       we say it selected candidate
  #       remove (current bucket count - target_count) childs of selected candidate and push selected candidate to target bucket
  #       break if bucket_parents_size == parents_count
  #       we repeat until we don't find bucket with count > target_count
  #       we look for bucket with count < target_count we say it current_bucket and take (parents_count - bucket_parents_size) members from bucket
  #       we say it selected candidate
  #       remove (target_count - current bucket count) childs of selected candidate
  #       break if bucket_parents_size == parents_count
  #       we repeat until we don't find bucket with count < target_count
  #     if bucket_parents_size > parents_count 
  #       we look for bucket with count < target_count we say it current_bucket and take (bucket_parents_size - parent count) members from bucket
  #       we say it selected candidate
  #       remove (target_count - current bucket count) childs of selected candidate
  #  if no 
  #     we do same as previous case assuming bucket_parents_size is zero
  #Finally we call clean_buckets_ary to remove all childs of remaining buckets. 
  #====================================================================================================================================

  def process_patch(parents_ary, children_hsh)
    parents_total_count = parents_ary.size
    parent_partitioned_counts_ary = get_parents_count_ary(parents_total_count, @percents_ary)
    buckets_ary = []
    children_hsh.each do |child|
      bucket = buckets_ary.find{ |bucket|  bucket[:count] == child[1].size}
      bucket.nil? ? buckets_ary << {count: child[1].size, parent_ids: [child[0]]}  :  bucket[:parent_ids] << child[0]
    end
    parents_ary_without_child = parents_ary - buckets_ary.map{|child| child[:parent_ids]}.flatten
    buckets_ary << {count: 0, parent_ids: parents_ary_without_child} unless parents_ary_without_child.empty?
    buckets_ary.sort_by!{|bucket| - bucket[:count]}
    add_remove_record_hash = {add: [], remove: []} # TODO : fix later : add_remove_record(parents_ary, @percents_ary, @counts_ary, buckets_ary)
    parent_partitioned_counts_ary.each_with_index do |partition, index|
      parent_ids = parents_ary.shift(partition)
      target_count = @counts_ary[index]
      parent_ids.each do |id|
        delta = target_count - (children_hsh[id].try(:size) || 0)
        next if delta == 0
        update_add_remove_record_hash(add_remove_record_hash[delta > 0 ? :add : :remove], id, delta)
      end
    end
    print_and_flush("add_remove_record_hash: #{add_remove_record_hash.inspect}")
    print_and_flush("\nSubdomain: #{@organization.subdomain}")
    remove_item(add_remove_record_hash[:remove])
    add_item(add_remove_record_hash[:add])
    buckets_ary
  end

  def update_add_remove_record_hash(pipeline, id, delta)
    delta = delta.abs
    data_hsh = pipeline.find { |x| x[:count] == delta }
    if data_hsh
      data_hsh[:candidate] << id
    else
      pipeline << {candidate: [id], count: delta}
    end
  end

  def destroy_objects_with_progress_print(objects_to_destroy)
    objects_to_destroy_size = objects_to_destroy.size.to_f
    objects_to_destroy.each_with_index do |object, index|
      print_and_flush("\r%-50s" % "Destroy completion : #{((index+1)*100.0/objects_to_destroy_size).round(4)}%")
      object.destroy
    end
  end

  def get_children_hash(scope_model, child_model, foreign_key, parent_ids)
    arel = scope_model.present? ? scope_model.send(child_model.pluralize.to_sym) : child_model.camelize.constantize
    arel.where(foreign_key.to_sym => parent_ids).pluck(foreign_key.to_sym).group_by{|x| x}
  end

  def delegate_work
    begin
      if @options[:args]["scope"] == "organization"
        @node_populator_class.new(@node, @options).patch
      elsif @options[:args]["scope"] == "program"
        @organization.reload.programs.each do |program|
          @options[:program] = program
          @program = program
          @node_populator_class.new(@node, @options).patch
        end
      end
    rescue => exception
      print_and_flush("Exception: #{exception}\n")
      print_and_flush("-- At node: #{@node}, options: #{@options.select{|k,v| [:organization, :args, :counts_ary, :percents_ary, :scope].include?(k)}.inspect}")
    end
  end

  def remove_item(remove_item_ary)
    remove_item_ary.each{|remove_item| send(@remove_item_callback, remove_item[:candidate], remove_item[:count], @options) unless (remove_item[:candidate].size.zero? || remove_item[:count].zero?)}
  end

  def add_item(add_item_ary)
    add_item_ary.each{|add_item| send(@add_item_callback, add_item[:candidate], add_item[:count], @options) unless (add_item[:candidate].size.zero? || add_item[:count].zero?)}
  end

  def get_parents_count_ary(parents_total_count, percent_ary)
    adjusted_percent_ary = percent_ary.map { |percent| (percent.is_a?(Array) ? percent[0] : percent) }
    child_count_ary = adjusted_percent_ary.map{|percent| [(parents_total_count * percent * 0.01).round, 1].max }
    result = []
    available = true
    child_count_ary.each do |value|
      if parents_total_count >= value && available
        result << value
        parents_total_count -= value
      else
        available = false
        result << 0
      end
    end
    result[result.index(0)] = parents_total_count if parents_total_count > 0 && result.index(0)
    percent_ary.each_with_index do |percent, index|
      if percent.is_a?(Array) && result[index] > percent[1]
        additional = result[index] - percent[1]
        result[index] = percent[1]
        remaining_ary_size = percent_ary.size - (index + 1)
        additional.times { |i| result[(index + 1) + (i % remaining_ary_size)] += 1 } if remaining_ary_size > 0
      end
    end
    result
  end

  def self.get_parents_count_ary(parents_total_count, percent_ary) # to do remove
    adjusted_percent_ary = percent_ary.map { |percent| (percent.is_a?(Array) ? percent[0] : percent) }
    child_count_ary = adjusted_percent_ary.map{|percent| [(parents_total_count * percent * 0.01).round, 1].max }
    result = []
    available = true
    child_count_ary.each do |value|
      if parents_total_count >= value && available
        result << value
        parents_total_count -= value
      else
        available = false
        result << 0
      end
    end
    result[result.index(0)] = parents_total_count if parents_total_count > 0 && result.index(0)
    percent_ary.each_with_index do |percent, index|
      if percent.is_a?(Array) && result[index] > percent[1]
        additional = result[index] - percent[1]
        result[index] = percent[1]
        remaining_ary_size = percent_ary.size - (index + 1)
        additional.times { |i| result[(index + 1) + (i % remaining_ary_size)] += 1 } if remaining_ary_size > 0
      end
    end
    result
  end

  def update_buckets(buckets_ary, target_count, parents_count, parents_ary)
    return {to_add: [{ candidate: parents_ary.shift(parents_count), count: target_count}], to_remove: []} if buckets_ary.blank?
    add_record = []
    remove_record = []
    target_bucket = get_target_bucket(target_count, buckets_ary)
    parents_count -= target_bucket[:parent_ids].size if target_bucket.present?
    current_bucket = find_current_bucket_above_target(target_count, buckets_ary)
    while parents_count > 0 && current_bucket.present?
      selected_candidates = current_bucket[:parent_ids].shift(parents_count)
      remove_record << {candidate: selected_candidates, count: (target_count - current_bucket[:count]).abs}
      parents_count -= selected_candidates.size
      buckets_ary.delete(current_bucket) if current_bucket[:parent_ids].empty?
      current_bucket = find_current_bucket_above_target(target_count, buckets_ary)
    end

    current_bucket = find_current_bucket_below_target(target_count, buckets_ary)
    while parents_count > 0 && current_bucket.present?
      selected_candidates = current_bucket[:parent_ids].shift(parents_count)
      parents_count -= selected_candidates.size
      add_record << {candidate: selected_candidates, count: (target_count - current_bucket[:count]).abs}
      buckets_ary.delete(current_bucket) if current_bucket[:parent_ids].empty?
      current_bucket = find_current_bucket_below_target(target_count, buckets_ary)
    end

    if parents_count < 0
      current_bucket = find_current_bucket_below_target(target_count, buckets_ary) || {}
      selected_candidates = target_bucket[:parent_ids].shift(parents_count.abs)
      current_bucket[:parent_ids] +=selected_candidates if current_bucket.present?
      remove_record << {candidate: selected_candidates, count: (target_count - current_bucket[:count].to_i).abs}
    end

    buckets_ary.delete(get_target_bucket(target_count, buckets_ary))
    {to_add: add_record, to_remove: remove_record}
  end

  def add_remove_record(parents_ary, percent_ary, children_count_ary, buckets_ary)
    add_remove_record_hash = {:add => [], :remove => []}
    parents_total_count = parents_ary.size
    parents_count_ary = get_parents_count_ary(parents_total_count, percent_ary)
    parents_count_ary[-1] -= parents_count_ary.sum - parents_total_count if parents_count_ary.sum > parents_total_count
    children_count_ary.each_with_index do |target_count, index|
      add_remove_record = update_buckets(buckets_ary, target_count, parents_count_ary[index], parents_ary)
      add_remove_record_hash[:add] += add_remove_record[:to_add]
      add_remove_record_hash[:remove] += add_remove_record[:to_remove]     
    end
    add_remove_record_hash[:remove] += clean_buckets_ary(buckets_ary)
    add_remove_record_hash
  end

  def clean_buckets_ary(buckets_ary)
    remove_record = []
    buckets_ary.each{|bucket| remove_record << {candidate: bucket[:parent_ids], count: bucket[:count]} unless bucket[:count].zero?}
    buckets_ary.clear
    remove_record
  end

  def find_current_bucket_above_target(bucket_count, buckets_ary)
    buckets_ary.find{|bucket| bucket[:count] > bucket_count}
  end

  def find_current_bucket_below_target(bucket_count, buckets_ary)
    buckets_ary.find{|bucket| bucket[:count] < bucket_count}
  end

  def get_target_bucket(bucket_count, buckets_ary)
    buckets_ary.find{|bucket| bucket[:count] == bucket_count}
  end
end