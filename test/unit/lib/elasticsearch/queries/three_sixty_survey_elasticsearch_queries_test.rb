require_relative './../../../../test_helper'

class ThreeSixtySurveyElasticsearchQueriesTest < ActiveSupport::TestCase

  def test_get_es_results_three_sixty_survey
    results = ThreeSixty::Survey.get_es_results(search_params: {}, filter: {}, skip_pagination: true)
    assert_equal_unordered [1, 2, 3, 4, 5], results.collect(&:id)

    results = ThreeSixty::Survey.get_es_results(search_params: {sort_field: "id", sort_order: "desc"}, filter: {}, skip_pagination: true)
    assert_equal [5, 4, 3, 2, 1], results.collect(&:id)

    results = ThreeSixty::Survey.get_es_results(search_params: {sort_field: "id", sort_order: "desc", page: 2, per_page: 2}, filter: {}, skip_pagination: false)
    assert_equal [3, 2], results.collect(&:id)

    surveys = ThreeSixty::Survey.get_es_results({search_params: {sort_field: "id", sort_order: "desc"}, filter: {state: "published"}})
    assert surveys.index(three_sixty_surveys(:survey_5)) < surveys.index(three_sixty_surveys(:survey_4))
    surveys = ThreeSixty::Survey.get_es_results({search_params: {sort_field: "id", sort_order: "desc"}, filter: {state: "drafted"}})
    assert surveys.index(three_sixty_surveys(:survey_3)) < surveys.index(three_sixty_surveys(:survey_2))

    survey_ids = ThreeSixty::Survey.get_es_results({search_params: {}, filter: { program_id: programs(:albers).id } }).collect(&:id)
    assert_equal programs(:albers).three_sixty_surveys.size, survey_ids.size
    assert_empty (survey_ids - programs(:albers).three_sixty_surveys.pluck(:id))
  end

  def test_get_es_results_three_sixty_survey_assessee
    results = ThreeSixty::SurveyAssessee.get_es_results(search_params: {}, filter: {}, skip_pagination: true)
    assert_equal_unordered [14, 5, 8, 9, 10, 12, 2, 4, 6, 15, 1, 7, 13, 3, 11], results.collect(&:id)

    results = ThreeSixty::SurveyAssessee.get_es_results(search_params: {sort_field: "id", sort_order: "desc"}, filter: {}, skip_pagination: true)
    assert_equal [15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1], results.collect(&:id)

    results = ThreeSixty::SurveyAssessee.get_es_results(search_params: {sort_field: "id", sort_order: "desc", page: 2, per_page: 2}, filter: {}, skip_pagination: false)
    assert_equal [13, 12], results.collect(&:id)
    # survey assessee index
    assessees = ThreeSixty::SurveyAssessee.get_es_results({search_params: {sort_field: "participant", sort_order: "desc"}, filter: {state: "published"}, skip_pagination: true})

    assert assessees.index(three_sixty_survey_assessees(:three_sixty_survey_assessees_11)) < assessees.index(three_sixty_survey_assessees(:three_sixty_survey_assessees_12))

    assessees = ThreeSixty::SurveyAssessee.get_es_results({search_params: {sort_field: "expires", sort_order: "desc"}, filter: {state: "published"}})
    assert assessees.index(three_sixty_survey_assessees(:three_sixty_survey_assessees_12)) < assessees.index(three_sixty_survey_assessees(:three_sixty_survey_assessees_11))

    assessees = ThreeSixty::SurveyAssessee.get_es_results({search_params: {sort_field: "issued", sort_order: "desc"}, filter: {state: "published"}})
    assert assessees.index(three_sixty_survey_assessees(:three_sixty_survey_assessees_12)) > assessees.index(three_sixty_survey_assessees(:three_sixty_survey_assessees_11))

    assessees = ThreeSixty::SurveyAssessee.get_es_results({search_params: {sort_field: "participant", sort_order: "desc"}, filter: {state: "drafted"}})
    assert assessees.index(three_sixty_survey_assessees(:three_sixty_survey_assessees_2)) < assessees.index(three_sixty_survey_assessees(:three_sixty_survey_assessees_7))

    assessees = ThreeSixty::SurveyAssessee.get_es_results({search_params: {sort_field: "expires", sort_order: "desc"}, filter: {state: "drafted"}})
    assert assessees.index(three_sixty_survey_assessees(:three_sixty_survey_assessees_8)) < assessees.index(three_sixty_survey_assessees(:three_sixty_survey_assessees_1))

    assessees = ThreeSixty::SurveyAssessee.get_es_results({search_params: {sort_field: "issued", sort_order: "desc"}, filter: {state: "drafted"}})
    assert assessees.index(three_sixty_survey_assessees(:three_sixty_survey_assessees_1)) > assessees.index(three_sixty_survey_assessees(:three_sixty_survey_assessees_8))
    # survey assessee with program filter
    survey_assessee_ids = ThreeSixty::SurveyAssessee.get_es_results({filter: { program_id: programs(:albers).id } , skip_pagination: true, search_params: {}}).collect(&:id)
    assert_equal programs(:albers).three_sixty_surveys.collect(&:survey_assessees).flatten.size, survey_assessee_ids.size
    assert_empty survey_assessee_ids - ThreeSixty::SurveyAssessee.where(three_sixty_survey_id: programs(:albers).three_sixty_surveys.pluck(:id)).pluck(:id)
  end
end