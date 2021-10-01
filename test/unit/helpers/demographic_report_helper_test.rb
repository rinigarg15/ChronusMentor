require_relative './../../test_helper.rb'

class DemographicReportHelperTest < ActionView::TestCase
  include TranslationsService

  def setup
    super
    @current_program = programs(:albers)
    @report_view_columns = @current_program.report_view_columns.for_demographic_report
  end

  def test_get_demographic_report_table_header
    content = get_demographic_report_table_header(@report_view_columns, ReportViewColumn::DemographicReport::Key::COUNTRY, "asc")
    assert_select_helper_function "th[class=\"sort_asc pointer cjs_sortable_column\"][data-sort-param=\"country\"][data-url=\"/reports/demographic_report.js\"][id=\"sort_by_country\"]",  content, { text: "Country" }
    #centered display for columns with counts
    assert_select_helper_function "th[class=\"sort_both pointer cjs_sortable_column text-center\"][data-sort-param=\"all_users_count\"][data-url=\"/reports/demographic_report.js\"][id=\"sort_by_all_users_count\"]", content, {text: "All Users"}

    content = get_demographic_report_table_header(@report_view_columns, ReportViewColumn::DemographicReport::Key::MENTORS_COUNT, "desc")
    assert_select_helper_function "th[class=\"sort_both pointer cjs_sortable_column\"][data-sort-param=\"country\"][data-url=\"/reports/demographic_report.js\"][id=\"sort_by_country\"]", content, { text: "Country" }
    #centered display for columns with counts
    assert_select_helper_function "th[class=\"sort_desc pointer cjs_sortable_column text-center\"][data-sort-param=\"mentors_count\"][data-url=\"/reports/demographic_report.js\"][id=\"sort_by_mentors_count\"]", content

    @current_program = programs(:primary_portal)
    @report_view_columns = programs(:primary_portal).report_view_columns.for_demographic_report
    content = get_demographic_report_table_header(@report_view_columns, ReportViewColumn::DemographicReport::Key::COUNTRY, "asc")
    assert_select_helper_function "th[class=\"sort_both pointer cjs_sortable_column text-center\"][data-sort-param=\"all_users_count\"][data-url=\"/reports/demographic_report.js\"][id=\"sort_by_all_users_count\"]",  content,  text: "All Users"
    assert_select_helper_function "th[class=\"sort_both pointer cjs_sortable_column text-center\"][data-sort-param=\"employees_count\"][data-url=\"/reports/demographic_report.js\"][id=\"sort_by_employees_count\"]", content, text: "Workers"
  end

  def test_get_demographic_report_table_row
    location = users(:f_mentor).location

    all_role_ids = @current_program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME, RoleConstants::ADMIN_NAME]).collect(&:id)
    mentor_role_ids = @current_program.get_roles(RoleConstants::MENTOR_NAME).collect(&:id)
    student_role_ids = @current_program.get_roles(RoleConstants::STUDENT_NAME).collect(&:id)

    users_scope = User.active_or_pending.where(:program_id => @current_program.id)
    locations_scope = Location.where.not(lat:nil, lng: nil, country: nil)
    profile_answer_scope = ProfileAnswer.joins("INNER JOIN users ON (profile_answers.ref_obj_type = 'Member' and profile_answers.ref_obj_id = users.member_id) INNER JOIN locations ON (profile_answers.location_id = locations.id) INNER JOIN role_references ON (role_references.ref_obj_type = 'User' and role_references.ref_obj_id = users.id)").merge(locations_scope).merge(users_scope)

    select_queries = ["country, full_address, lat, lng, city, COUNT(DISTINCT users.member_id) AS all_users_count","SUM(CASE WHEN role_references.role_id IN (#{mentor_role_ids.join(", ")}) THEN 1 ELSE 0 end) AS mentor_users_count","SUM(CASE WHEN role_references.role_id IN (#{student_role_ids.join(", ")}) THEN 1 ELSE 0 end) AS student_users_count"]

    all_roles_scope = RoleReference.where(role_id:all_role_ids)
    all_locations = profile_answer_scope.select(select_queries).merge(all_roles_scope).group(:location_id)
    all_grouped_locations = all_locations.group_by(&:country)
    content = get_demographic_report_table_row(location.country, all_grouped_locations, @report_view_columns, 0)
    assert_match "<td><a class=\"cjs_country_field no-underline\" data-country-index=\"0\" href=\"javascript:void(0)\">India</a></td><td class=\"text-center\">2</td><td class=\"text-center\">2</td><td class=\"text-center\">0</td>", content
  end

  private

  def _Employees
    "Workers"
  end
end