MailerTag.register_tags(:subprogram_tags) do |t|
  t.tag :subprogram_name, :description => Proc.new{'feature.email.tags.subprogram_tags.subprogram_name.description'.translate}, :example => Proc.new{|program| 'feature.email.tags.subprogram_tags.subprogram_name.example_v1'.translate(:program_name => program.name)} do
    @program.name
  end

  t.tag :url_subprogram, :description => Proc.new{'feature.email.tags.subprogram_tags.url_subprogram.description'.translate}, :example => Proc.new{"http://www.chronus.com"} do
    program_root_url(:subdomain => @organization.subdomain)
  end

  t.tag :subprogram_or_program_name, :description => Proc.new{'feature.email.tags.subprogram_tags.subprogram_or_program_name.description'.translate}, :eval_tag => true do
    (@program || @organization).name
  end

  t.tag :url_subprogram_or_program, :description => Proc.new{'feature.email.tags.subprogram_tags.url_subprogram_or_program.description'.translate}, :example => Proc.new{"http://www.chronus.com"} do
    if @program
      url_subprogram
    else
      url_program
    end
  end

  t.tag :url_program_login, :description => Proc.new{'feature.email.tags.subprogram_tags.url_program_login.description'.translate}, :example => Proc.new{"http://www.chronus.com"} do
    login_url(:subdomain => @program.organization.subdomain, :root => @program.root)
  end
end
