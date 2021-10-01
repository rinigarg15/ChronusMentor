require_relative './../../../../../test_helper'

class PopulatorTaskTest < ActiveSupport::TestCase
  def test_initialize
    assert_raise RuntimeError do
      populator_task = PopulatorTask.new("article")
    end
    percents_ary = [50, 25, 25]
    counts_ary = [3, 2, 1]
    populator_task = PopulatorTask.new("article", {parent: "member", percents_ary: percents_ary, counts_ary: counts_ary})
    assert_equal "article", populator_task.instance_variable_get('@node')
    assert_equal "ArticlePopulator", populator_task.instance_variable_get('@node_populator_class').to_s
    assert_equal percents_ary, populator_task.instance_variable_get('@percents_ary')
    assert_equal counts_ary, populator_task.instance_variable_get('@counts_ary')
    assert_equal "member", populator_task.instance_variable_get('@parent')
    assert_nil populator_task.instance_variable_get('@program')
    assert_nil populator_task.instance_variable_get('@organization')
  end

  def test_process_patch
    org = programs(:org_primary)
    populator_task = PopulatorTask.new("article", {parent: "member", percents_ary: [50, 25, 25], counts_ary: [3, 2, 1], organization: org})
    members = org.members.collect(&:id)
    articles_hsh = org.articles.where(:author_id => members).select(:author_id).group_by(&:author_id)
    PopulatorTask.any_instance.stubs(:remove_item).returns(0)
    PopulatorTask.any_instance.stubs(:add_item).returns(0)
    PopulatorTask.any_instance.stubs(:add_remove_record).returns({:add => [], :remove => []})
    buckets_ary = populator_task.process_patch(members, articles_hsh) 
    buckets_ary2 = []
    org.members.each do |member|
      article_count = member.articles.count
      bucket = buckets_ary2.find{ |bucket|  bucket[:count] == article_count}
      bucket.nil? ? buckets_ary2 << {count: article_count,parent_ids: [member.id]}  :  bucket[:parent_ids] << member.id
    end
    assert_equal buckets_ary2.sort_by{|bucket| -bucket[:count]}, buckets_ary
  end

  def test_patch
    populator_task = PopulatorTask.new("article", {parent: "member", percents_ary: [50, 25, 25], counts_ary: [3, 2, 1]})
    assert_raise RuntimeError do
      populator_task.patch
    end
  end

  def test_add_remove_record
    populator_task = PopulatorTask.new("article", {parent: "member", percents_ary: [50, 25, 25], counts_ary: [3, 2, 1]})
    parents_ary = [1 , 2, 3, 4, 5, 6, 7, 8, 9, 10]
    children_count_ary = [3, 2, 1]
    percent_ary = [50, 25, 25]
    buckets_ary = []
    add_remove_record_hash = populator_task.add_remove_record(parents_ary, percent_ary, children_count_ary, buckets_ary)
    assert_equal [{:candidate=>[1, 2, 3, 4, 5], :count=>3}, {:candidate=>[6, 7, 8], :count=>2}, {:candidate=>[9, 10], :count=>1}], add_remove_record_hash[:add]
    assert_equal [], add_remove_record_hash[:remove]

    parents_ary = [1 , 2, 3, 4, 5, 6, 7, 8, 9, 10]
    children_count_ary = [3, 2, 1]
    percent_ary = [50, 25, 25]
    buckets_ary = [{count: 3, parent_ids: [6, 7, 8, 9, 10]}, {count: 2, parent_ids: [5, 4, 3]}, {count: 1, parent_ids: [2, 1]}]
    add_remove_record_hash = populator_task.add_remove_record(parents_ary, percent_ary, children_count_ary, buckets_ary)
    assert_equal [], add_remove_record_hash[:add]
    assert_equal [], add_remove_record_hash[:remove]

    parents_ary = [1 , 2, 3, 4, 5, 6, 7, 8, 9, 10]
    children_count_ary = [4, 2, 1]
    percent_ary = [50, 25, 25]
    buckets_ary = [{count: 3, parent_ids: [6, 7, 8, 9, 10]}, {count: 2, parent_ids: [5, 4, 3]}, {count: 1, parent_ids: [2, 1]}]
    add_remove_record_hash = populator_task.add_remove_record(parents_ary, percent_ary, children_count_ary, buckets_ary)
    assert_equal [{:candidate=>[6, 7, 8, 9, 10], :count=> 1}], add_remove_record_hash[:add]
    assert_equal [], add_remove_record_hash[:remove]

    parents_ary = [1 , 2, 3, 4, 5, 6, 7, 8, 9, 10]
    children_count_ary = [3, 2]
    percent_ary = [75, 25]
    buckets_ary = [{count: 4, parent_ids: [6, 7, 8, 9, 10]}, {count: 2, parent_ids: [5, 4, 3]}, {count: 1, parent_ids: [2, 1]}]
    add_remove_record_hash = populator_task.add_remove_record(parents_ary, percent_ary, children_count_ary, buckets_ary)
    assert_equal [{:candidate=>[5, 4, 3], :count=>1}, {:candidate=>[2, 1], :count=>1}], add_remove_record_hash[:add]
    assert_equal [{:candidate=>[6, 7, 8, 9, 10], :count=>1}], add_remove_record_hash[:remove]

    parents_ary = [1 , 2, 3, 4, 5, 6, 7, 8, 9, 10]
    children_count_ary = [3, 2, 1]
    percent_ary = [25, 50, 25]
    buckets_ary = [{count: 3, parent_ids: [6, 7, 8, 9, 10, 5, 4, 3]}, {count: 2, parent_ids: [2, 1]}, {count: 1, parent_ids: []}]
    add_remove_record_hash = populator_task.add_remove_record(parents_ary, percent_ary, children_count_ary, buckets_ary)
    assert_equal [], add_remove_record_hash[:add]
    assert_equal [{:candidate=>[6, 7, 8, 9, 10], :count=>1}, {:candidate=>[2, 1], :count=>1}], add_remove_record_hash[:remove]

    parents_ary = [1 , 2, 3, 4, 5, 6, 7, 8, 9, 10]
    children_count_ary = [3, 2, 1]
    percent_ary = [25, 25, 50]
    buckets_ary = [{count: 3, parent_ids: [5, 4, 3]}, {count: 2, parent_ids: [6, 7, 8, 9, 10]}, {count: 1, parent_ids: [2, 1]}]
    add_remove_record_hash = populator_task.add_remove_record(parents_ary, percent_ary, children_count_ary, buckets_ary)
    assert_equal [], add_remove_record_hash[:add]
    assert_equal [{:candidate=>[6, 7], :count=>1}], add_remove_record_hash[:remove]

    parents_ary = [1 , 2, 3, 4, 5, 6, 7, 8, 9, 10]
    children_count_ary = [10, 2]
    percent_ary = [50, 50]
    buckets_ary = [{count: 3, parent_ids: [5, 4, 3]}, {count: 2, parent_ids: [ 8, 9, 10]}, {count: 1, parent_ids: [2, 1, 6, 7]}]
    add_remove_record_hash = populator_task.add_remove_record(parents_ary, percent_ary, children_count_ary, buckets_ary)
    assert_equal [{:candidate=>[5, 4, 3], :count=>7}, {:candidate=>[8, 9], :count=>8}, {:candidate=>[2, 1, 6, 7], :count=>1}], add_remove_record_hash[:add]
    assert_equal [], add_remove_record_hash[:remove]

    parents_ary = [1 , 2, 3, 4, 5, 6, 7, 8, 9, 10]
    children_count_ary = [3]
    percent_ary = [75]
    buckets_ary = [{count: 10, parent_ids: [5, 4, 3, 8, 9]}, {count: 2, parent_ids: [ 2, 1, 6, 7]}]
    add_remove_record_hash = populator_task.add_remove_record(parents_ary, percent_ary, children_count_ary, buckets_ary)
    assert_equal [{:candidate=>[2, 1, 6], :count=>1}], add_remove_record_hash[:add]
    assert_equal [{:candidate=>[5, 4, 3, 8, 9], :count=>7}, {:candidate=>[7], :count=>2}], add_remove_record_hash[:remove]
  end

  def test_update_buckets
    populator_task = PopulatorTask.new("article", {parent: "member", percents_ary: [50, 25, 25], counts_ary: [3, 2, 1]})
    parents_ary = [1 , 2, 3, 4, 5, 6, 7, 8, 9, 10]
    buckets_ary = []
    target_count = 3
    parents_ary_count = 5
    add_remove_record = populator_task.update_buckets(buckets_ary, target_count, parents_ary_count, parents_ary)
    add_record = add_remove_record[:to_add]
    remove_record = add_remove_record[:to_remove]
    assert_false add_record.empty?
    assert remove_record.empty?
    assert_equal [1, 2, 3, 4, 5], add_record.first[:candidate]
    assert_equal target_count, add_record.first[:count]
    buckets_ary = [{count: 2, parent_ids: [6, 7, 8, 9, 10]}, {count: 1, parent_ids: [1, 2, 3, 4, 5]}]
    target_count = 3
    parents_ary_count = 5
    add_remove_record = populator_task.update_buckets(buckets_ary, target_count, parents_ary_count, parents_ary)
    add_record = add_remove_record[:to_add]
    remove_record = add_remove_record[:to_remove]
    assert_false add_record.empty?
    assert remove_record.empty?
    assert_equal [6, 7, 8, 9, 10], add_record.first[:candidate]
    assert_equal 1, add_record.first[:count]

    buckets_ary = [{count: 3, parent_ids: [6, 7, 8, 9, 10]}, {count: 1, parent_ids: [1, 2, 3, 4, 5]}]
    target_count = 2
    parents_ary_count = 5
    add_remove_record = populator_task.update_buckets(buckets_ary, target_count, parents_ary_count, parents_ary)
    add_record = add_remove_record[:to_add]
    remove_record = add_remove_record[:to_remove]
    assert_false remove_record.empty?
    assert add_record.empty?
    assert_equal [6, 7, 8, 9, 10], remove_record.first[:candidate]
    assert_equal 1, remove_record.first[:count]

    buckets_ary = [{count: 3, parent_ids: [6, 7, 8, 9, 10]}, {count: 1, parent_ids: [1, 2, 3, 4, 5]}]
    target_count = 2
    parents_ary_count = 3
    add_remove_record = populator_task.update_buckets(buckets_ary, target_count, parents_ary_count, parents_ary)
    add_record = add_remove_record[:to_add]
    remove_record = add_remove_record[:to_remove]
    assert_false remove_record.empty?
    assert add_record.empty?
    assert_equal [6, 7, 8], remove_record.first[:candidate]
    assert_equal 1, remove_record.first[:count]

    buckets_ary = [{count: 3, parent_ids: [6, 7, 8, 9, 10]}, {count: 1, parent_ids: [1, 2, 3, 4, 5]}]
    target_count = 2
    parents_ary_count = 7
    add_remove_record = populator_task.update_buckets(buckets_ary, target_count, parents_ary_count, parents_ary)
    add_record = add_remove_record[:to_add]
    remove_record = add_remove_record[:to_remove]
    assert_false remove_record.empty?
    assert_false add_record.empty?
    assert_equal [6, 7, 8, 9, 10], remove_record.first[:candidate]
    assert_equal 1, remove_record.first[:count]
    assert_equal [1, 2], add_record.first[:candidate]
    assert_equal 1, add_record.first[:count]

    buckets_ary = [{count: 2, parent_ids: [6, 7, 8, 9, 10]}, {count: 1, parent_ids: [1, 2, 3, 4, 5]}]
    target_count = 2
    parents_ary_count = 7
    add_remove_record = populator_task.update_buckets(buckets_ary, target_count, parents_ary_count, parents_ary)
    add_record = add_remove_record[:to_add]
    remove_record = add_remove_record[:to_remove]
    assert remove_record.empty?
    assert_false add_record.empty?
    assert_equal [1, 2], add_record.first[:candidate]
    assert_equal 1, add_record.first[:count]

    buckets_ary = [{count: 2, parent_ids: [6, 7, 8, 9, 10]}, {count: 1, parent_ids: [1, 2, 3, 4, 5]}]
    target_count = 1
    parents_ary_count = 5
    add_remove_record  = populator_task.update_buckets(buckets_ary, target_count, parents_ary_count, parents_ary)
    add_record = add_remove_record[:to_add]
    remove_record = add_remove_record[:to_remove]
    assert remove_record.empty?
    assert add_record.empty?

    buckets_ary = [{count: 2, parent_ids: [6, 7, 8, 9, 10]}, {count: 1, parent_ids: [1, 2, 3, 4, 5]}]
    target_count = 2
    parents_ary_count = 3
    add_remove_record = populator_task.update_buckets(buckets_ary, target_count, parents_ary_count, parents_ary)
    add_record = add_remove_record[:to_add]
    remove_record = add_remove_record[:to_remove]
    assert_false remove_record.empty?
    assert add_record.empty?
    assert_equal [6, 7], remove_record.first[:candidate]
    assert_equal 1, remove_record.first[:count]
    assert_equal buckets_ary.last[:parent_ids], [1, 2, 3, 4, 5, 6, 7]

    buckets_ary = [{count: 2, parent_ids: [6, 7, 8, 9, 10]}, {count: 1, parent_ids: [1, 2, 3, 4, 5]}]
    target_count = 1
    parents_ary_count = 3
    add_remove_record = populator_task.update_buckets(buckets_ary, target_count, parents_ary_count, parents_ary)
    add_record = add_remove_record[:to_add]
    remove_record = add_remove_record[:to_remove]
    assert_false remove_record.empty?
    assert add_record.empty?
    assert_equal [1, 2], remove_record.first[:candidate]
    assert_equal 1, remove_record.first[:count]
  end

  def test_find_current_bucket_above_target
    populator_task = PopulatorTask.new("article", {parent: "member", percents_ary: [50, 25, 25], counts_ary: [3, 2, 1]})
    buckets_ary = [{count: 3, parent_ids: [6, 7, 8, 9, 10]}, {count: 1, parent_ids: [1, 2, 3, 4, 5]}]
    assert_nil populator_task.find_current_bucket_above_target(4, buckets_ary)
    assert_nil populator_task.find_current_bucket_above_target(3, buckets_ary)
    assert_equal 3, populator_task.find_current_bucket_above_target(2, buckets_ary)[:count]
  end

  def test_find_current_bucket_below_target
    populator_task = PopulatorTask.new("article", {parent: "member", percents_ary: [50, 25, 25], counts_ary: [3, 2, 1]})
    buckets_ary = [{count: 3, parent_ids: [6, 7, 8, 9, 10]}, {count: 1, parent_ids: [1, 2, 3, 4, 5]}]
    assert_nil populator_task.find_current_bucket_below_target(1, buckets_ary)
    assert_nil populator_task.find_current_bucket_below_target(0, buckets_ary)
    assert_equal 1, populator_task.find_current_bucket_below_target(3, buckets_ary)[:count]
  end

  def test_get_target_bucket
    populator_task = PopulatorTask.new("article", {parent: "member", percents_ary: [50, 25, 25], counts_ary: [3, 2, 1]})
    buckets_ary = [{count: 3, parent_ids: [6, 7, 8, 9, 10]}, {count: 1, parent_ids: [1, 2, 3, 4, 5]}]
    assert_nil populator_task.get_target_bucket(2, buckets_ary)
    assert_equal buckets_ary.first, populator_task.get_target_bucket(3, buckets_ary)
  end

  def test_clean_buckets_ary
    populator_task = PopulatorTask.new("article", {parent: "member", percents_ary: [50, 25, 25], counts_ary: [3, 2, 1]})
    buckets_ary = [{count: 3, parent_ids: [6, 7, 8, 9, 10]}, {count: 1, parent_ids: [1, 2, 3, 4, 5]}]
    remove_record = populator_task.clean_buckets_ary(buckets_ary)
    assert_equal [], buckets_ary
  end

  def test_get_parents_count_ary
    populator_task = PopulatorTask.new("article", {parent: "member", percents_ary: [50, 25, 25], counts_ary: [3, 2, 1]})
    assert_equal [7, 3], populator_task.get_parents_count_ary(10, [70, 30])
    assert_equal [1, 1, 0], populator_task.get_parents_count_ary(2, [10, 80, 10])
  end
end