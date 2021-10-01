require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/experiences_helper"

class ExperiencesHelperTest < ActionView::TestCase
  include ProfileAnswersHelper

  def test_formatted_work_experience_in_listing
    exp = Experience.new(:company => "Microsoft")
    assert_dom_equal("<div class=\"work_exp\"><i class=\"fa fa-suitcase fa-fw m-r-xs\"></i><strong class=\"company\">Microsoft</strong></div>", formatted_work_experience_in_listing(exp))

    exp.job_title = 'Programmer'
    assert_dom_equal(%Q{<div class="work_exp"><div class="title_and_date"><i class=\"fa fa-suitcase fa-fw m-r-xs\"></i><strong class="company">Microsoft</strong><span class="text-muted">, </span><span class="title">Programmer</span></div></div>}, formatted_work_experience_in_listing(exp))

    exp.start_year = '1995'
    assert_dom_equal(%Q{<div class="work_exp"><div class="title_and_date"><i class=\"fa fa-suitcase fa-fw m-r-xs\"></i><strong class="company">Microsoft</strong><span class="text-muted">, </span><span class="title">Programmer</span><span class="text-muted p-l-xxs p-r-xxs">|</span><span class="text-muted work_date">1995</span></div></div>}, formatted_work_experience_in_listing(exp))

    exp.end_year = '1998'
    assert_dom_equal(%Q{<div class="work_exp"><div class="title_and_date"><i class=\"fa fa-suitcase fa-fw m-r-xs\"></i><strong class="company">Microsoft</strong><span class="text-muted">, </span><span class="title">Programmer</span><span class="text-muted p-l-xxs p-r-xxs"">|</span><span class="text-muted work_date">1995 - 1998</span></div></div>}, formatted_work_experience_in_listing(exp))

    exp.start_month = 3
    assert_dom_equal(%Q{<div class="work_exp"><div class="title_and_date"><i class=\"fa fa-suitcase fa-fw m-r-xs\"></i><strong class="company">Microsoft</strong><span class="text-muted">, </span><span class="title">Programmer</span><span class="text-muted p-l-xxs p-r-xxs"">|</span><span class="text-muted work_date">Mar 1995 - 1998</span></div></div>}, formatted_work_experience_in_listing(exp))

    exp.job_title = nil
    assert_dom_equal(%Q{<div class="work_exp"><div class="title_and_date"><i class=\"fa fa-suitcase fa-fw m-r-xs\"></i><strong class="company">Microsoft</strong><span class="text-muted">, </span><span class="text-muted work_date">Mar 1995 - 1998</span></div></div>}, formatted_work_experience_in_listing(exp))
  end

  def test_fetch_workex_month
    assert_equal "", fetch_workex_month(0)
    month_options_for_select[1..-1].each do |arr|
      assert_equal arr[0], fetch_workex_month(arr[1])
    end
  end
end