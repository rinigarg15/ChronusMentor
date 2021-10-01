include CommonTags
MailerTag.register_tags(:global_tags) do |t|
  t.tag :receiver_name, :description => Proc.new{'feature.email.tags.global_tags.receiver_name'.translate}, :example => Proc.new{'feature.email.content.test_email.receiver_name'.translate} do
    @user_name
  end

  t.tag :receiver_first_name, :description => Proc.new{'feature.email.tags.global_tags.receiver_first_name'.translate}, :example => Proc.new{'feature.email.content.test_email.receiver_name'.translate.split(" ").first} do
    @user_first_name.to_s
  end

  t.tag :receiver_last_name, :description => Proc.new{'feature.email.tags.global_tags.receiver_last_name'.translate}, :example => Proc.new{'feature.email.content.test_email.receiver_name'.translate.split(" ").last} do
    @user_last_name.to_s
  end

  t.get_common_organization_tags

  t.tag :url_program, :description => Proc.new{'feature.email.tags.global_tags.url_program'.translate}, :eval_tag => true do
    ActionMailer::Base.default_url_options.delete(:root)
    url = root_organization_url(:subdomain => @organization.subdomain)
    set_host_name_for_urls(@organization, @program)
    return url
  end

  t.tag :current_time, :description => Proc.new{'feature.email.tags.global_tags.current_time'.translate}, :eval_tag => true do
    DateTime.localize(Time.now, format: :short)
  end
end
