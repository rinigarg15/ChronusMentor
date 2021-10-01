MailerTag.register_tags(:customized_terms_tags) do |t|
  t.tag :customized_mentors_term, :description => Proc.new{'feature.email.tags.custom_terms.customized_mentors_term'.translate}, :eval_tag => true do
    @_mentors_string
  end

  t.tag :customized_mentees_term, :description => Proc.new{'feature.email.tags.custom_terms.customized_mentees_term'.translate}, :eval_tag => true do
    @_mentees_string
  end

  t.tag :customized_mentors_term_caps, :description => Proc.new{'feature.email.tags.custom_terms.customized_mentors_term_caps'.translate}, :eval_tag => true do
    @_Mentors_string
  end

  t.tag :customized_mentees_term_caps, :description => Proc.new{'feature.email.tags.custom_terms.customized_mentees_term_caps'.translate}, :eval_tag => true do
    @_Mentees_string
  end

  t.tag :customized_mentor_term_caps, :description => Proc.new{'feature.email.tags.custom_terms.customized_mentor_term_caps'.translate}, :eval_tag => true do
    @_Mentor_string
  end

  t.tag :customized_mentee_term_caps, :description => Proc.new{'feature.email.tags.custom_terms.customized_mentee_term_caps'.translate}, :eval_tag => true do
    @_Mentee_string
  end

  t.tag :customized_mentor_term, :description => Proc.new{'feature.email.tags.custom_terms.customized_mentor_term'.translate}, :eval_tag => true do
    @_mentor_string
  end

  t.tag :customized_mentee_term, :description => Proc.new{'feature.email.tags.custom_terms.customized_mentee_term'.translate}, :eval_tag => true do
    @_mentee_string
  end

  t.tag :customized_mentor_term_articleized, :description => Proc.new{'feature.email.tags.custom_terms.customized_mentor_term_articleized'.translate}, :eval_tag => true do
    @_a_mentor_string
  end

  t.tag :customized_mentee_term_articleized, :description => Proc.new{'feature.email.tags.custom_terms.customized_mentee_term_articleized'.translate}, :eval_tag => true do
    @_a_mentee_string
  end

  t.tag :customized_mentor_term_articleized_caps, :description => Proc.new{'feature.email.tags.custom_terms.customized_mentor_term_articleized_caps'.translate}, :eval_tag => true do
    @_a_Mentor_string
  end

  t.tag :customized_articles_term, :description => Proc.new{'feature.email.tags.custom_terms.customized_articles_term'.translate}, :eval_tag => true do
    @_articles_string
  end

  t.tag :customized_article_term, :description => Proc.new{'feature.email.tags.custom_terms.customized_article_term'.translate}, :eval_tag => true do
    @_article_string
  end

  t.tag :customized_article_term_articleized, :description => Proc.new{'feature.email.tags.custom_terms.customized_article_term_articleized'.translate}, :eval_tag => true do
    @_a_article_string
  end

  t.tag :customized_admin_term_articleized, :description => Proc.new{'feature.email.tags.custom_terms.customized_admin_term_articleized'.translate}, :eval_tag => true do
    @_a_admin_string
  end

  t.tag :customized_admin_term, :description => Proc.new{'feature.email.tags.custom_terms.customized_admin_term'.translate}, :eval_tag => true do
    @_admin_string
  end

  t.tag :customized_admin_term_pluralized, :description => Proc.new{'feature.email.tags.custom_terms.customized_admin_term_pluralized'.translate}, :eval_tag => true do
    @_admins_string
  end

  t.tag :customized_admin_term_capitalized, :description => Proc.new{'feature.email.tags.custom_terms.customized_admin_term_capitalized'.translate}, :eval_tag => true do
    @_Admin_string
  end

  t.tag :customized_mentoring_connection_term, :description => Proc.new{|program| 'feature.email.tags.custom_terms.customized_mentoring_connection_term_v1'.translate(program.return_custom_term_hash)}, :eval_tag => true do
    @_mentoring_connection_string
  end

  t.tag :customized_mentoring_connections_term, :description => Proc.new{|program| 'feature.email.tags.custom_terms.customized_mentoring_connections_term_v1'.translate(program.return_custom_term_hash)}, :eval_tag => true do
    @_mentoring_connections_string
  end

  t.tag :customized_mentoring_connection_term_capitalized, :description => Proc.new{|program| 'feature.email.tags.custom_terms.customized_mentoring_connection_term_capitalized_v1'.translate(program.return_custom_term_hash)}, :eval_tag => true do
    @_Mentoring_Connection_string
  end

  t.tag :customized_mentoring_connections_term_capitalized, :description => Proc.new{|program| 'feature.email.tags.custom_terms.customized_mentoring_connections_term_capitalized_v1'.translate(program.return_custom_term_hash)}, :eval_tag => true do
    @_Mentoring_Connections_string
  end

  t.tag :customized_connection_term_articleized, :description => Proc.new{'feature.email.tags.custom_terms.customized_connection_term_articleized'.translate}, :eval_tag => true do
    @_a_mentoring_connection_string
  end

  t.tag :customized_meeting_term, :description => Proc.new{'feature.email.tags.custom_terms.customized_meeting_term'.translate}, :eval_tag => true do
    @_meeting_string
  end

  t.tag :customized_meetings_term, :description => Proc.new{'feature.email.tags.custom_terms.customized_meetings_term'.translate}, :eval_tag => true do
    @_meetings_string
  end

  t.tag :customized_meeting_term_capitalized, :description => Proc.new{'feature.email.tags.custom_terms.customized_meeting_term_capitalized'.translate}, :eval_tag => true do
    @_Meeting_string
  end

  t.tag :customized_meeting_term_articleized, :description => Proc.new{'feature.email.tags.custom_terms.customized_meeting_term_articleized'.translate}, :eval_tag => true do
    @_a_meeting_string
  end

  t.tag :customized_subprogram_term, :description => Proc.new{'feature.email.tags.custom_terms.customized_subprogram_term'.translate}, :eval_tag => true do
    @_program_string
  end

  t.tag :customized_subprograms_term, :description => Proc.new{'feature.email.tags.custom_terms.customized_subprograms_term'.translate}, :eval_tag => true do
    @_programs_string
  end

  t.tag :customized_subprogram_term_capitalized, :description => Proc.new{'feature.email.tags.custom_terms.customized_subprogram_term_capitalized'.translate}, :eval_tag => true do
    @_Program_string
  end

  t.tag :customized_subprogram_term_articleized, :description => Proc.new{'feature.email.tags.custom_terms.customized_subprogram_term_articleized'.translate}, :eval_tag => true do
    @_a_program_string
  end

  t.tag :customized_mentoring_term, :description => Proc.new{'feature.email.tags.custom_terms.customized_mentoring_term'.translate}, :eval_tag => true do
    @_mentoring_string
  end

  t.tag :customized_mentoring_term_capitalized, :description => Proc.new{'feature.email.tags.custom_terms.customized_mentoring_term_capitalized'.translate}, :eval_tag => true do
    @_Mentoring_string
  end

  t.tag :customized_mentoring_term_articleized, :description => Proc.new{'feature.email.tags.custom_terms.customized_mentoring_term_articleized'.translate}, :eval_tag => true do
    @_a_mentoring_string
  end

end