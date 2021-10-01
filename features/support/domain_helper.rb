Before('@stub_cd_sub_domain') do
  @default_sub_domain_name = EMAIL_HOST_SUBDOMAIN
  EMAIL_HOST_SUBDOMAIN.replace('nch')
end

After('@stub_cd_sub_domain') do
  EMAIL_HOST_SUBDOMAIN.replace(@default_sub_domain_name)
  @default_sub_domain_name = nil
end
