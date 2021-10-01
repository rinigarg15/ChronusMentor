module NavigationHelpers
  # Maps a name to a path. Used by the
  #
  #   When /^I go to (.+)$/ do |page_name|
  #
  # step definition in web_steps.rb
  #
  def path_to(page_name)
    case page_name

    when /^programs page$/
      '/programs'

    when /^"([^\"]*)":"([^\"]*)" program/
      org = Program::Domain.get_organization(DEFAULT_HOST_NAME, $1)
      program = org.programs.find_by(root: $2)
      return program_root_url(:host => DEFAULT_DOMAIN_NAME, :subdomain => $1, :root => program.root)

    when /^the home\s?page$/
      '/'

    when /^feature listing page in ([^\"]*):([^\"]*) program$/
      org = Program::Domain.get_organization(DEFAULT_HOST_NAME, $1)
      program = org.programs.find_by(root: $2)
      return edit_program_path(:host => DEFAULT_DOMAIN_NAME, :subdomain => $1, :root => program.root, :tab => ProgramsController::SettingsTabs::FEATURES)

    when /^(.*) page in ([^\"]*):([^\"]*) program$/
      arg1, arg2, arg3 = $1, $2, $3
      path_components = arg1.split(/\s+/)
      return self.send(path_components.push('path').join('_').to_sym, :subdomain => arg2, :root => arg3)

    # Add more mappings here.
    # Here is an example that pulls values out of the Regexp:
    #
    #   when /^(.*)'s profile page$/i
    #     user_profile_path(User.find_by(login: $1))

    else
      begin
        page_name =~ /^the (.*) page$/
        path_components = $1.split(/\s+/)
        self.send(path_components.push('path').join('_').to_sym)
      rescue NoMethodError, ArgumentError
        raise "Can't find mapping from \"#{page_name}\" to a path.\n" +
          "Now, go and add a mapping in #{__FILE__}"
      end
    end
  end
end

World(NavigationHelpers)
