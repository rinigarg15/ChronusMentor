MailerTag.register_tags(:admin_and_mentor_url_tags) do |t|
  t.tag :mentor_url,  description: Proc.new { "email_translations.mentor_request_rejected.tags.mentor_url.description".translate }, example: Proc.new {"http://www.chronus.com"} do
      user_url(@mentor, subdomain: @organization.subdomain, root: @program.root)
  end

  t.tag :admin_url, :description => Proc.new{'email_translations.mentor_request_rejected.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
    get_contact_admin_path(@program, url_params: { subdomain: @organization.subdomain, root: @program.root }, only_url: true)
  end
end