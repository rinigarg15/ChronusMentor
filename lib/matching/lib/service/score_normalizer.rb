class ScoreNormalizer
  attr_reader :input_range, :scale_factor

  def initialize(in_range)
    @input_range = in_range
    output_range_diff = output_range.last - output_range.first
    input_range_diff = input_range.last - input_range.first
    # set NaN to infinite.NaN arises when both numerator(float) and denominator are zero.
    @scale_factor = (input_range_diff.zero? ? 1 : output_range_diff).to_f / input_range_diff
  end

  def normalize(value)
    if scale_factor.infinite?
      output_range.last
    else
      output_range.first + (value - input_range.first) * scale_factor
    end
  end

  def output_range
    [Matching::SCORE_RANGE.first, input_range.first].max..[Matching::SCORE_RANGE.last, input_range.last].max
  end

  def self.normalize_for(student_ids = [], mentor_ids = [], scores = [])
    @results = {}
    if student_ids.present? && mentor_ids.present? && scores.present?
      @mentor_ids_to_slice = mentor_ids.map(&:to_s)
      min_score, max_score = scores.compact.minmax.collect(&:to_f)
      @normalizer = ScoreNormalizer.new(min_score..max_score)
      student_ids.each do |student_id|
        normalize_result_for(student_id)
      end
    end
    @results
  end

  private

  def self.normalize_result_for(student_id)
    mentor_hash = Matching::Database::Score.new.get_mentor_hash(student_id)
    if mentor_hash.present?
      mentor_hash = mentor_hash.slice(*@mentor_ids_to_slice)
      result = {}
      mentor_hash.each do |mentor_id, score_with_match|
        result[mentor_id.to_i] = score_with_match[1] ? 0 : (@normalizer.normalize(score_with_match[0]).to_f.round(2) * 100).to_i
      end
      @results[student_id] = result
    end
  end
end
