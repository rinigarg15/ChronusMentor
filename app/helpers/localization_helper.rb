module LocalizationHelper

  def calculate_program_score(score_hash, prog_or_org)
    score = score_hash[prog_or_org.id].second.zero? ? 0 : (score_hash[prog_or_org.id].first*100/score_hash[prog_or_org.id].second)
  end
end