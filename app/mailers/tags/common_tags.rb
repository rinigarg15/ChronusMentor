module CommonTags
  def get_common_user_tags
    tag :user_firstname, description: Proc.new{'feature.email.tags.campaign_tags.user_firstname.description'.translate}, example: Proc.new{'feature.email.tags.campaign_tags.user_firstname.example_html'.translate}, name: Proc.new{'feature.email.tags.campaign_tags.user_firstname.name'.translate} do
      @member.first_name
    end

    tag :user_lastname, description: Proc.new{'feature.email.tags.campaign_tags.user_lastname.description'.translate}, example: Proc.new{'feature.email.tags.campaign_tags.user_lastname.example_html'.translate}, name: Proc.new{'feature.email.tags.campaign_tags.user_lastname.name'.translate} do
      @member.last_name
    end

    tag :user_name, description: Proc.new{'feature.email.tags.campaign_tags.user_name.description'.translate}, example: Proc.new{'feature.email.tags.campaign_tags.user_name.example_html'.translate}, name: Proc.new{'feature.email.tags.campaign_tags.user_name.name'.translate} do
      @member.name
    end
    
    tag :user_email, description: Proc.new{'feature.email.tags.campaign_tags.user_email.description'.translate}, example: Proc.new{'feature.email.tags.campaign_tags.user_email.example_html'.translate}, name: Proc.new{'feature.email.tags.campaign_tags.user_email.name'.translate}  do
      @member.email
    end
    
    tag :user_role, description: Proc.new{'feature.email.tags.campaign_tags.user_role.description'.translate}, example: Proc.new{|program| 'feature.email.tags.campaign_tags.user_role.example_html'.translate(program.return_custom_term_hash)}, name: Proc.new{'feature.email.tags.campaign_tags.user_role.name'.translate}  do
      RoleConstants.human_role_string(@user.role_names, {program: @program})
    end
  end

  def get_contact_admin_url_tag
    tag :url_contact_admin, description: Proc.new{'feature.email.tags.campaign_tags.url_contact_admin.description'.translate}, example: Proc.new{'http://www.chronus.com'}, name: Proc.new{'feature.email.tags.campaign_tags.url_contact_admin.name'.translate} do
      get_contact_admin_path(@program, url_params: {subdomain: @organization.subdomain, root: @program.root, host: @organization.domain})
    end
  end

  def get_common_organization_tags
    tag :program_name, description: Proc.new{'feature.email.tags.common_tags.program_name.description'.translate}, name: Proc.new{'feature.email.tags.common_tags.program_name.name'.translate}, eval_tag: true do
      @organization.name
    end
  end

  def get_common_group_tags
    tag :group_name, description: Proc.new{|program| "feature.email.tags.campaign_tags.group_name.description".translate(program.return_custom_term_hash)}, name: Proc.new{|program| 'feature.email.tags.campaign_tags.group_name.name'.translate(program.return_custom_term_hash)}, example: Proc.new{"feature.email.tags.campaign_tags.group_name.example".translate} do
      @group.name
    end

    tag :mentoring_area_button, description: Proc.new{|program| 'feature.email.tags.common_tags.mentoring_area_button.description'.translate(program.return_custom_term_hash)}, name: Proc.new{|program| 'feature.email.tags.common_tags.mentoring_area_button.name'.translate(program.return_custom_term_hash)}, example: Proc.new{|program| call_to_action_example("feature.email.tags.common_tags.mentoring_area_button.visit_your_connection".translate(mentoring_connection: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase)) } do
      call_to_action("feature.email.tags.common_tags.mentoring_area_button.visit_your_connection".translate(mentoring_connection: @_mentoring_connection_string),  group_url(@group, {subdomain: @organization.subdomain, root: @program.root, host: @organization.domain}), "button-large btn btn-large btn-primary")
    end
  end
end