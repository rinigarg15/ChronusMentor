module Common::RakeModule::Utils

  def self.fetch_programs_and_organization(domain, subdomain, program_roots = "")
    organization = self.fetch_organization(domain, subdomain)
    programs = []

    program_roots.split(',').each do |program_root|
      program = organization.programs.find_by(root: program_root)
      raise "Invalid Program Root!" if program.blank?
      programs << program
    end
    [programs, organization]
  end

  def self.execute_task(options = {})
    start_time = Time.now
    @skip_es_delta_indexing = true if options[:suspend_ts_delta]
    Delayed::Worker.delay_jobs = !!options[:async_dj]
    ActionMailer::Base.perform_deliveries = !!options[:send_mails]

    ActiveRecord::Base.transaction do
      GlobalizationUtils.run_in_locale(options[:locale] || I18n.default_locale) do
        yield
      end
    end
    puts "Time Taken: #{Time.now - start_time} seconds." unless options[:skip_benchmark]
  end

  def self.print_success_messages(messages)
    self.print_messages(messages, :green)
  end

  def self.print_alert_messages(messages)
    self.print_messages(messages, :cyan)
  end

  def self.print_error_messages(messages)
    self.print_messages(messages, :red)
  end

  def self.establish_cloned_db_connection(cloned_db)
    return if cloned_db.blank?
    db_configurations = ActiveRecord::Base.configurations[Rails.env].dup
    db_configurations["database"] = cloned_db
    ActiveRecord::Base.establish_connection(db_configurations)
  end

  def self.export_to_csv(file_name, headers, array)
    return unless array.present?
    CSV.open(file_name, "w+") do |csv|
      csv << headers
      array.each{ |a| csv << a }
    end
    print_success_messages "Exported to #{file_name}"
  end

  private

  def self.fetch_organization(domain, subdomain)
    domain = domain.presence || DEFAULT_DOMAIN_NAME
    organization = Program::Domain.get_organization(domain, subdomain)
    raise "Invalid Domain and Subdomain!" if organization.blank?
    organization
  end

  def self.print_messages(messages, color_method)
    messages = [messages].flatten
    messages.each { |message| puts message.send(color_method) }
  end

end