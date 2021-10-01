require_relative './../test_helper.rb'

class CustomizedTermsControllerTest < ActionController::TestCase

  def test_update_all_non_super_user
    current_member_is :f_admin
    assert_permission_denied do
      put :update_all
    end
  end

  def test_update_all_org_level
    current_member_is :f_admin
    login_as_super_user
    org = programs(:org_primary)
    program_term = org.customized_terms.find_by(term_type: CustomizedTerm::TermType::PROGRAM_TERM)

    assert_equal "Program", program_term.term
    assert_equal "program", program_term.term_downcase
    assert_equal "programs", program_term.pluralized_term_downcase
    assert_equal "Programs", program_term.pluralized_term
    assert_equal "a Program", program_term.articleized_term
    assert_equal "a program", program_term.articleized_term_downcase

    put :update_all, params: { "customized_term"=>{"#{program_term.id}"=>{:term=>"Track", :pluralized_term=>"Trackss", :articleized_term=>"aa Track"}}, :program_scope=>"false", format: :js}

    program_term = org.customized_terms.find_by(term_type: CustomizedTerm::TermType::PROGRAM_TERM)

    assert_equal "Track", program_term.term
    assert_equal "track", program_term.term_downcase
    assert_equal "trackss", program_term.pluralized_term_downcase
    assert_equal "Trackss", program_term.pluralized_term
    assert_equal "aa Track", program_term.articleized_term
    assert_equal "aa track", program_term.articleized_term_downcase
    assert_match /<a target=\"_blank\" href=\"\/about\">Track Overview pages<\/a>/, flash[:notice]
    assert_no_match(/Closure reasons/, flash[:notice])
  end

  def test_update_all_org_level_with_only_basic_terms
    current_member_is :f_admin
    login_as_super_user
    org = programs(:org_primary)
    program_term = org.customized_terms.find_by(term_type: CustomizedTerm::TermType::PROGRAM_TERM)

    assert_equal "Program", program_term.term
    assert_equal "program", program_term.term_downcase
    assert_equal "programs", program_term.pluralized_term_downcase
    assert_equal "Programs", program_term.pluralized_term
    assert_equal "a Program", program_term.articleized_term
    assert_equal "a program", program_term.articleized_term_downcase

    put :update_all, params: { "customized_term"=>{"#{program_term.id}"=>{:term=>"Track"}}, :program_scope=>"false", format: :js}

    program_term = org.customized_terms.find_by(term_type: CustomizedTerm::TermType::PROGRAM_TERM)

    assert_equal "Track", program_term.term
    assert_equal "track", program_term.term_downcase
    assert_equal "tracks", program_term.pluralized_term_downcase
    assert_equal "Tracks", program_term.pluralized_term
    assert_equal "a Track", program_term.articleized_term
    assert_equal "a track", program_term.articleized_term_downcase
  end

  def test_update_all_prog_level_terms
    current_user_is :f_admin
    login_as_super_user
    program = programs(:albers)
    connection_term = program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM)
    mentor_term = program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME)

    assert_equal "Mentoring Connection", connection_term.term
    assert_equal "mentoring connection", connection_term.term_downcase
    assert_equal "mentoring connections", connection_term.pluralized_term_downcase
    assert_equal "Mentoring Connections", connection_term.pluralized_term
    assert_equal "a Mentoring Connection", connection_term.articleized_term
    assert_equal "a mentoring connection", connection_term.articleized_term_downcase

    assert_equal "Mentor", mentor_term.term
    assert_equal "mentor", mentor_term.term_downcase
    assert_equal "mentors", mentor_term.pluralized_term_downcase
    assert_equal "Mentors", mentor_term.pluralized_term
    assert_equal "a Mentor", mentor_term.articleized_term
    assert_equal "a mentor", mentor_term.articleized_term_downcase

    put :update_all, params: { "customized_term"=>{"#{connection_term.id}"=>{:term=>"Link", :pluralized_term=>"Linkss", :articleized_term=>"aa Link"}, "#{mentor_term.id}"=>{:term=>"Car", :pluralized_term=>"Carss", :articleized_term=>"aa Car"}}, :program_scope=>"true", format: :js}

    connection_term = program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM)
    mentor_term = program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME)

    assert_equal "Link", connection_term.term
    assert_equal "link", connection_term.term_downcase
    assert_equal "linkss", connection_term.pluralized_term_downcase
    assert_equal "Linkss", connection_term.pluralized_term
    assert_equal "aa Link", connection_term.articleized_term
    assert_equal "aa link", connection_term.articleized_term_downcase

    assert_equal "Car", mentor_term.term
    assert_equal "car", mentor_term.term_downcase
    assert_equal "carss", mentor_term.pluralized_term_downcase
    assert_equal "Carss", mentor_term.pluralized_term
    assert_equal "aa Car", mentor_term.articleized_term
    assert_equal "aa car", mentor_term.articleized_term_downcase
    assert_match /<a target=\"_blank\" href=\"\/p\/albers\/about\">Program Overview pages<\/a>/, flash[:notice]
    assert_match /<a target=\"_blank\" href=\"\/p\/albers\/edit\?tab=3\">Link Closure reasons<\/a>/, flash[:notice]
  end

  def test_update_all_prog_level_with_only_basic_terms
    current_user_is :f_admin
    login_as_super_user
    program = programs(:albers)
    connection_term = program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM)
    mentor_term = program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME)
    old_mentee_term = program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME)

    assert_equal "Mentoring Connection", connection_term.term
    assert_equal "mentoring connection", connection_term.term_downcase
    assert_equal "mentoring connections", connection_term.pluralized_term_downcase
    assert_equal "Mentoring Connections", connection_term.pluralized_term
    assert_equal "a Mentoring Connection", connection_term.articleized_term
    assert_equal "a mentoring connection", connection_term.articleized_term_downcase

    assert_equal "Mentor", mentor_term.term
    assert_equal "mentor", mentor_term.term_downcase
    assert_equal "mentors", mentor_term.pluralized_term_downcase
    assert_equal "Mentors", mentor_term.pluralized_term
    assert_equal "a Mentor", mentor_term.articleized_term
    assert_equal "a mentor", mentor_term.articleized_term_downcase

    put :update_all, params: { "customized_term"=>{"#{connection_term.id}"=>{:term=>"Link"}, "#{mentor_term.id}"=>{:term=>"Car"}}, :program_scope=>"true", format: :js}

    connection_term = program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM)
    mentor_term = program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME)
    new_mentee_term = program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME)
    org_connection_term = program.organization.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM)

    assert_equal "Link", connection_term.term
    assert_equal "link", connection_term.term_downcase
    assert_equal "links", connection_term.pluralized_term_downcase
    assert_equal "Links", connection_term.pluralized_term
    assert_equal "a Link", connection_term.articleized_term
    assert_equal "a link", connection_term.articleized_term_downcase

    assert_equal "Car", mentor_term.term
    assert_equal "car", mentor_term.term_downcase
    assert_equal "cars", mentor_term.pluralized_term_downcase
    assert_equal "Cars", mentor_term.pluralized_term
    assert_equal "a Car", mentor_term.articleized_term
    assert_equal "a car", mentor_term.articleized_term_downcase

    #org level custom term should not change
    assert_equal "Mentoring Connection", org_connection_term.term
    assert_equal "mentoring connection", org_connection_term.term_downcase
    assert_equal "mentoring connections", org_connection_term.pluralized_term_downcase
    assert_equal "Mentoring Connections", org_connection_term.pluralized_term
    assert_equal "a Mentoring Connection", org_connection_term.articleized_term
    assert_equal "a mentoring connection", org_connection_term.articleized_term_downcase

    #other terms should not get affected
    assert_equal old_mentee_term, new_mentee_term
  end

  def test_update_all_stand_alone_prog
    current_member_is :foster_admin
    login_as_super_user
    program = programs(:foster)
    org = programs(:org_foster)
    program_term = org.customized_terms.find_by(term_type: CustomizedTerm::TermType::PROGRAM_TERM)
    resource_term = program.term_for(CustomizedTerm::TermType::RESOURCE_TERM)

    connection_term = program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM)
    mentor_term = program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME)
    assert_equal "Mentor", mentor_term.term
    assert_equal "Resource", resource_term.term
    assert_equal "Mentoring Connection", connection_term.term
    assert_equal "Program", program_term.term
    put :update_all, params: { "customized_term"=>{"#{connection_term.id}"=>{:term=>"Link"}, "#{mentor_term.id}"=>{:term=>"Car"}, "#{program_term.id}"=>{:term=>"Track"}, "#{resource_term.id}"=>{:term=>"File"}}, :program_scope=>"false", format: :js}

    program_term = org.customized_terms.find_by(term_type: CustomizedTerm::TermType::PROGRAM_TERM)
    resource_term = program.term_for(CustomizedTerm::TermType::RESOURCE_TERM)

    connection_term = program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM)
    mentor_term = program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME)

    assert_equal "Car", mentor_term.term
    assert_equal "File", resource_term.term
    assert_equal "Link", connection_term.term
    assert_equal "Track", program_term.term
    assert_match /<a target=\"_blank\" href=\"\/p\/main\/about\">Track Overview pages<\/a>/, flash[:notice]
    assert_match /<a target=\"_blank\" href=\"\/p\/main\/edit\?tab=3\">Link Closure reasons<\/a>/, flash[:notice]
  end

  def test_update_all_non_stand_alone_prog
    current_member_is :f_admin
    login_as_super_user
    program = programs(:albers)
    org = programs(:org_primary)
    program_term = org.customized_terms.find_by(term_type: CustomizedTerm::TermType::PROGRAM_TERM)
    resource_term = program.term_for(CustomizedTerm::TermType::RESOURCE_TERM)

    connection_term = program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM)
    mentor_term = program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME)

    assert_equal "Mentor", mentor_term.term
    assert_equal "Resource", resource_term.term
    assert_equal "Mentoring Connection", connection_term.term
    assert_equal "Program", program_term.term

    put :update_all, params: { "customized_term"=>{"#{connection_term.id}"=>{:term=>"Link"}, "#{mentor_term.id}"=>{:term=>"Car"}, "#{program_term.id}"=>{:term=>"Track"}, "#{resource_term.id}"=>{:term=>"File"}}, :program_scope=>"false", format: :js}

    program_term = org.customized_terms.find_by(term_type: CustomizedTerm::TermType::PROGRAM_TERM)
    resource_term = program.term_for(CustomizedTerm::TermType::RESOURCE_TERM)

    connection_term = program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM)
    mentor_term = program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME)

    assert_equal "Mentor", mentor_term.term
    assert_equal "Resource", resource_term.term
    assert_equal "Mentoring Connection", connection_term.term
    assert_equal "Track", program_term.term
  end

end
