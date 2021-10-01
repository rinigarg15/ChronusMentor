class PopulatorManagerIntegrationTest
  include PopulatorManagerIntegrationTestUtils

  module Result
    PASS = "PASS"
    FAIL = "FAIL"
  end

  def initialize_manager(options={})
    manager = PopulatorManager.new({:spec_file_path => PopulatorManager::SPEC_PATH})
    test_spec_hash = YAML.load_file(TEST_SPEC_FILE)
    manager.nodes.deep_merge!(test_spec_hash) unless options[:ignore_test_spec]
    manager
  end

  def test
    @end_result = Result::PASS
    populator_puts "Testing populator With Given Spec"
    run_end_to_end_test
    populator_puts "Testing populator With Same Spec Again"
    run_end_to_end_test if @end_result == Result::PASS
    populator_puts "Testing up scaling Feature of populator With changed Spec"
    run_end_to_end_test({:change_spec => true}) if @end_result == Result::PASS
    populator_puts "Testing down scaling Feature of populator With changed Spec"
    run_end_to_end_test if @end_result == Result::PASS
    populator_puts "END RESULT : #{@end_result}"
  end

  def compare_pairs(child_parent_count, ratio_from_db)
    child_parent_count.each_with_index do |cp, index|
      if ratio_from_db.include?(cp)
        ratio_from_db = ratio_from_db - [cp]
        child_parent_count = child_parent_count - [cp]
      else
        return false
      end
    end
    (child_parent_count.empty? && ratio_from_db.empty?) ? true : false
  end

  def compare_pairs_for_portal(node, child_parent_count, ratio_from_db)
    return ratio_from_db.blank? if EXCLUDED_FOR_PORTAL.include?(node)
    compare_pairs(child_parent_count, ratio_from_db)
  end

  def compare_counts_common(node, parent, parent_key, child_model, percent_array, count_array, parent_model_type, options={})
    options[:parent_scope_column] ||= "id"
    parent_models = parent.camelize.constantize.where(options[:parent_scope_column].to_s => parent_model_type.id).to_a
    options[:additional_selects].each do |select_query|
      parent_models.select!(&select_query.to_sym)
    end
    parent_model_count = parent_models.size
    parent_model_ids = parent_models.collect(&:id)
    parent_count = PopulatorTask.get_parents_count_ary(parent_model_count, percent_array) # update_parent_count(parent_count, parent_model_count)
    child_parent_count = build_array(parent_count, count_array)

    if INDIVIDUAL_LIST.include?(node)
      compare_counts_individual(node, parent, parent_key, child_model, percent_array, count_array,parent_model_type, options)
      return
    end

    begin
      ratio_from_db = child_model.camelize.constantize.where("#{parent_key}_id".to_sym => parent_model_ids).group("#{parent_key}_id").count.group_by{|k, v|  v}.sort.map{|k,v| [k, v.size]}
      valid = if parent_model_type.is_a?(CareerDev::Portal)
        compare_pairs_for_portal(node, child_parent_count, ratio_from_db)
      else
        compare_pairs(child_parent_count, ratio_from_db)
      end
      if valid
        populator_puts "."
      else
        populator_puts "F"
        options[:fail_list].push node
        options[:mismatch_hash][child_model] = [parent, child_parent_count, ratio_from_db]
        return
      end
    rescue => e
      populator_puts "E"
      options[:errors_hash][node] = options[:errors_hash][node] ? options[:errors_hash][node].append(e.message) : [e.message]
      return
    end
  end

  def compare_counts(node, parent, parent_key, child_model, percent_array, count_array, options)
    if options[:scope]
      if options[:scope] == "organization"
        org = options[:organization]
        compare_counts_common(node, parent, parent_key, child_model, percent_array, count_array, org, options)
      elsif options[:scope] == "program"
        org = options[:organization]
        org.programs.each do |program|
          compare_counts_common(node, parent, parent_key, child_model, percent_array, count_array, program, options)
        end
      end
    options[:pass_list].push node
    end
  end

  def read_spec_and_compare(manager)
    mismatch_hash = {}
    errors_hash = {}
    fail_list = []
    pass_list = []
    @nodes =  manager.nodes
    Organization.all.each do |organization|
      type = organization.subdomain.gsub(/[0-9]/,'')
      models = @nodes.keys - TEST_IGNORE_LIST
      models = update_features_enabled(models, type, @nodes["organization"][type].keys.select{|key| key.include?("_enabled?")})
      models.each do |node|
        child_model = @nodes[node]["model"] ? @nodes[node]["model"] : node
        parent = @nodes[@nodes[node]["parent"]]["model"] || @nodes[node]["parent"]
        parent_key = @nodes[node]["parent_key"] || @nodes[node]["parent"]
        percent_array = @nodes[node]["percent"]
        count_array = @nodes[node]["count"]
        scope = @nodes[node]["scope"]
        scope_column = @nodes[node]["scope_column"]
        parent_scope_column =  @nodes[@nodes[node]["parent"]]["scope_column"]
        additional_selects = @nodes[node]["additional_selects"] || []

        options = {:child_model => child_model, :percent_array => percent_array, :count_array => count_array,
                   :mismatch_hash => mismatch_hash, :fail_list => fail_list, :errors_hash => errors_hash,
                   :scope => scope, :scope_column => scope_column, :parent_scope_column => parent_scope_column,
                   :additional_selects => additional_selects, :pass_list => pass_list, :organization => organization,
                   :nodes => @nodes, :type => type}

        compare_counts(node, parent, parent_key, child_model, percent_array, count_array, options) 
      end
    end
    print_errors(mismatch_hash, fail_list, errors_hash)
  end

  def print_errors(mismatch_hash, fail_list, errors_hash)
    @end_result = Result::FAIL if !fail_list.empty? || !errors_hash.empty?
    populator_puts "\n\nFound #{fail_list.uniq.size} mismatches\n"
    populator_puts fail_list.uniq.inspect
    populator_puts "!!!!Populator not populated according to given spec!!!!" unless fail_list.size.zero? 
    populator_puts "\n\nFound #{errors_hash.size} errors\n"
    errors_hash.each do |key, value|
      populator_puts "\n#{key} ===> #{value}\n"
    end
    populator_puts "!!!! Error occured while spec match!!!!" unless errors_hash.size.zero?
  end

  def run_end_to_end_test(options = {})
    manager = initialize_manager
    if options[:change_spec]
      manager.nodes["group"]["count"] = [2] # changing groups per mentoring model
      manager.nodes["qa_question"]["percent"] = [100]
      manager.nodes["qa_question"]["count"] = [10] # changing forums per program
    end
    manager.populate
    populator_puts "\n*** Populator :: Finished Populating data"
    populator_puts "\n*** Populator :: Integration Test\n"
    read_spec_and_compare(manager)
  end

  def update_features_enabled(models, org_type, features)
    # models -= @nodes["organization"][org_type]["program_event_feature_models"] unless @nodes["organization"][org_type]["program_event_enabled?"]
    features.each do |feature|
      feature_models = feature.gsub("enabled?", "feature_models")
      models -= @nodes["organization"][org_type][feature_models] unless @nodes["organization"][org_type][feature]
    end
    models
  end
end