require_relative './../../../test_helper'

class ScoreNormalizerTest < ActiveSupport::TestCase
  def test_output_range
    normalizer = ScoreNormalizer.new 0.1..0.9
    assert_equal 0.1..0.9, normalizer.output_range

    normalizer = ScoreNormalizer.new 0.2..0.6
    assert_equal 0.2..0.9, normalizer.output_range

    normalizer = ScoreNormalizer.new 0.15..0.95
    assert_equal 0.15..0.95, normalizer.output_range

    normalizer = ScoreNormalizer.new 0.05..0.85
    assert_equal 0.1..0.9, normalizer.output_range

    normalizer = ScoreNormalizer.new 0.6..0.6
    assert_equal 0.6..0.9, normalizer.output_range
  end

  def test_scale_factor
    normalizer = ScoreNormalizer.new 0.1..0.9
    assert_in_delta 1.0, normalizer.scale_factor

    normalizer = ScoreNormalizer.new 0.2..0.6
    assert_in_delta 1.75, normalizer.scale_factor

    normalizer = ScoreNormalizer.new 0.15..0.95
    assert_in_delta 1, normalizer.scale_factor

    normalizer = ScoreNormalizer.new 0.05..0.85
    assert_in_delta 1, normalizer.scale_factor

    normalizer = ScoreNormalizer.new 0.6..0.6
    assert normalizer.scale_factor.infinite?, 'scale factor should be infinite'
  end

  def test_normalize
    normalizer = ScoreNormalizer.new 0.1..0.9
    assert_in_delta 0.55, normalizer.normalize(0.55)

    normalizer = ScoreNormalizer.new 0.2..0.6
    assert_in_delta 0.8125, normalizer.normalize(0.55)

    normalizer = ScoreNormalizer.new 0.15..0.95
    assert_in_delta 0.55, normalizer.normalize(0.55)

    normalizer = ScoreNormalizer.new 0.05..0.85
    assert_in_delta 0.6, normalizer.normalize(0.55)

    normalizer = ScoreNormalizer.new 0.6..0.6
    assert_in_delta 0.9, normalizer.normalize(0.55)
  end

  def test_normalize_for
    program = programs(:albers)
    student = users(:f_student)
    mentor = users(:f_mentor)
    student_ids = program.student_users.pluck(:id)
    mentor_ids = program.mentor_users.pluck(:id)
    reset_cache(student)
    reset_cache(users(:f_mentor_student))
    min_max =  [nil, 0.0]

    results = ScoreNormalizer.normalize_for()
    assert_equal({}, results)
    
    results = ScoreNormalizer.normalize_for([student.id], [], min_max)
    assert_equal({}, results)

    results = ScoreNormalizer.normalize_for([], [mentor.id], min_max)
    assert_equal({}, results)
    
    results = ScoreNormalizer.normalize_for([student.id], [mentor.id], min_max)
    assert_equal({2=>{3=>90}}, results)

    results = ScoreNormalizer.normalize_for(student_ids, [mentor.id], min_max)
    assert_equal_unordered student_ids, results.keys
    assert_equal_unordered [mentor.id], results.values.collect(&:keys).flatten.uniq
    assert_equal_unordered [90], results.values.collect(&:values).flatten.uniq

    results = ScoreNormalizer.normalize_for([student.id], mentor_ids, min_max)
    assert_equal_unordered [student.id], results.keys
    assert_equal_unordered mentor_ids, results.values.collect(&:keys).flatten.uniq
    assert_equal [90], results.values.collect(&:values).flatten.uniq

    results = ScoreNormalizer.normalize_for(student_ids, mentor_ids, min_max)
    assert_equal_unordered student_ids, results.keys
    assert_equal_unordered mentor_ids, results.values.collect(&:keys).flatten.uniq
    assert_equal_unordered [90, 0], results.values.collect(&:values).flatten.uniq
  end

  def test_normalize_for_min_max
    program = programs(:albers)
    student = users(:f_student)
    mentor = users(:f_mentor)
    student_ids = program.student_users.pluck(:id)
    mentor_ids = program.mentor_users.pluck(:id)
    reset_cache(student)
    reset_cache(users(:f_mentor_student))
    min_max = [0.0, 0.8]

    results = ScoreNormalizer.normalize_for([], [], min_max)
    assert_equal({}, results)
    
    results = ScoreNormalizer.normalize_for([student.id], [], min_max)
    assert_equal({}, results)

    results = ScoreNormalizer.normalize_for([], [mentor.id], min_max)
    assert_equal({}, results)
    
    results = ScoreNormalizer.normalize_for([student.id], [mentor.id], min_max)    
    assert_equal({2=>{3=>10}}, results)

    results = ScoreNormalizer.normalize_for(student_ids, [mentor.id], min_max)
    assert_equal_unordered student_ids, results.keys
    assert_equal_unordered [mentor.id], results.values.collect(&:keys).flatten.uniq
    assert_equal_unordered [10], results.values.collect(&:values).flatten.uniq

    results = ScoreNormalizer.normalize_for([student.id], mentor_ids, min_max)
    assert_equal_unordered [student.id], results.keys
    assert_equal_unordered mentor_ids, results.values.collect(&:keys).flatten.uniq
    assert_equal [10], results.values.collect(&:values).flatten.uniq

    results = ScoreNormalizer.normalize_for(student_ids, mentor_ids, min_max)
    assert_equal_unordered student_ids, results.keys
    assert_equal_unordered mentor_ids, results.values.collect(&:keys).flatten.uniq
    assert_equal_unordered [10, 0], results.values.collect(&:values).flatten.uniq
  end  

  def test_when_scale_factor_is_nan
    #Handle  NaN as infinite. 0.97 leads to scale factor numerator of 0.0 (0.97-0.97)
    normalizer = ScoreNormalizer.new 0.97..0.97
    assert normalizer.scale_factor.infinite?, 'scale factor should be infinite'
  end

end
