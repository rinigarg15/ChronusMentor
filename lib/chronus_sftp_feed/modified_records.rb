module ChronusSftpFeed
  module ModifiedRecords

    RESCUED_ERRORS = {
      tags: "User tags are not handled.",
      header: "The header is not mapped with db."
    }

    private

    # Exports DB data into file and compares with original file and returns only the modified data in chunks.
    def get_modified_chunks(config, total_chunks)
      @config = config
      start_time = Time.now
      ChronusSftpFeed::Migrator.logger "Getting modified records at #{start_time}\n"
      @headers = total_chunks[0][0].keys
      @headers -= @config.ignore_column_headers if @config.ignore_column_headers.present?
      begin
        sql_query = generate_sql_query_from_headers
        db_file = create_db_file_from_query(sql_query)
        formatted_file = create_formatted_file(total_chunks)
        modified_file = create_modified_file(db_file, formatted_file)
        modified_chunks = SmarterCSV.process(modified_file, @config.csv_options.symbolize_keys)
      rescue => error
        if (Rails.env.development? || Rails.env.test?) && !error.message.in?(ChronusSftpFeed::ModifiedRecords::RESCUED_ERRORS.values)
          raise error
        else
          ChronusSftpFeed::Migrator.logger "Returning the total_chunks due to error #{error.message}. Time taken: #{((Time.now - start_time)/60).round(2)} minutes\n"
          return total_chunks
        end
      ensure
        delete_generated_files([db_file,formatted_file, modified_file])
      end
      ChronusSftpFeed::Migrator.logger "Finished Getting Modified Chunks in: #{((Time.now - start_time)/60).round(2)} minutes\n"
      modified_chunks
    end

    # Compares the DB file and formatted file and creates a file with records that is present in formatted file but not in db file.
    def create_modified_file(db_file, formatted_file)
      modified_file = "#{Rails.root}/tmp/sftp_#{@config.organization.subdomain || @config.organization.domain}_modified_#{Time.now.to_s.parameterize(separator: '_')}.csv"
      raise if system("awk 'FNR==NR {a[$0]++; next} !a[$0]' #{db_file} #{formatted_file} > #{modified_file}").nil?
      modified_file
    end

    # Creates a file with chunks from original file formatted to compare with db file.
    def create_formatted_file(total_chunks)
      formatted_file = "#{Rails.root}/tmp/sftp_#{@config.organization.subdomain || @config.organization.domain}_formatted_#{Time.now.to_s.parameterize(separator: '_')}.csv"
      CSV.open(formatted_file, 'a+', {force_quotes: true}) do |csv|
        csv << @headers
        total_chunks.each do |chunk|
          chunk.each do |record|
            record = record.reject{|key, _value| key.in?(@config.ignore_column_headers) } if @config.ignore_column_headers.present?
            if @config.empty_row_data_for_value_match.present?
              @config.empty_row_data_for_value_match.each do |column, value_to_clear|
                record[column] = nil if (record[column] && record[column] == value_to_clear)
              end
            end
            csv << record.values
          end
        end
      end
      formatted_file
    end

    # Exports DB date into a file from the query
    def create_db_file_from_query(query)
      db_file = "#{Rails.root}/tmp/sftp_#{@config.organization.subdomain || @config.organization.domain}_db_#{Time.now.to_s.parameterize(separator: '_')}.csv"
      query = query.gsub('`','')
      execute_query_and_format(query, db_file)
      db_file
    end

    # Executes the query in mysql and converts the tabs to comma
    def execute_query_and_format(query, db_file)
      db_config = ActiveRecord::Base.connection_config
      system("MYSQL_PWD=#{db_config[:password]} mysql -u #{db_config[:username]} --database=#{db_config[:database]} --host=#{db_config[:host]} --batch -s -e \"#{query}\" | #{awk_tab_to_csv} > #{db_file}")
    end

    # Command to seperate tab seperated file to comma seperated with double quotes
    def awk_tab_to_csv
      "awk 'BEGIN{FS=\"\\t\"}{printf(\"\\n\\\"%s\\\"\",$1); for (i = 2; i <= NF; i++){printf \",\\\"%s\\\"\", $i}}'"
    end

    # Parses the headers and generates query to fetch data from db.
    def generate_sql_query_from_headers
      select_queries = []
      join_queries = []
      questions_map = get_questions_map

      # Get the select query and join query required for each header.
      @headers.each do |header|
        if @config.primary_key_header == header
          select_queries << primary_column_select(header)
          join_queries << primary_column_join
        elsif member_headers_hash.keys.include?(header)
          select_queries << members_column_select(header)
        elsif manager_headers_hash.keys.include?(header)
          select_queries << managers_column_select(header)
        elsif @config.location_question(@headers).try(:question_text) == header
          select_queries << location_column_select(header)
          join_queries << location_column_join
        elsif questions_map.keys.include?(header)
          if questions_map[header].education?
            select_queries << education_column_select(header, questions_map[header])
          elsif questions_map[header].experience?
            select_queries << experience_column_select(header, questions_map[header])
          else
            select_queries << profile_question_column_select(header, questions_map[header])
          end
          join_queries << profile_question_column_join(header, questions_map[header])
        elsif [@config.user_tags_header, @config.program_name_header].include?(header)
          raise ChronusSftpFeed::ModifiedRecords::RESCUED_ERRORS[:tags]
        else
          raise ChronusSftpFeed::ModifiedRecords::RESCUED_ERRORS[:header]
        end
      end
      join_queries << managers_column_join(@config.manager_question(@headers)) if @config.allow_manager_updates?(@headers)
      Member.select(select_queries).joins(join_queries.join(" ")).where(organization_id: @config.organization.id).where("members.state <> #{Member::Status::SUSPENDED}").to_sql
    end

    def get_questions_map
      profile_questions = @config.organization.profile_questions.joins(:translations).where("profile_question_translations.question_text IN (?) AND locale = ?", @headers + @config.supplement_questions_map.keys, I18n.default_locale.to_s)
      questions_map = {}
      profile_questions.each do |q|
        questions_map[q.question_text] = q
      end
      questions_map
    end

    def education_column_select(header, question)
      alias_name = "profile_answers_#{question.id}"
      "COALESCE((select group_concat(CONCAT_WS(',',#{ChronusSftpFeed::Service::MemberUpdater::ProfileFields::EDUCATION.join(',')}) SEPARATOR '--') from educations where educations.profile_answer_id = #{alias_name}.id), '') as '#{header}'"
    end

    def experience_column_select(header, question)
      alias_name = "profile_answers_#{question.id}"
      "COALESCE((select group_concat(CONCAT_WS(',',#{ChronusSftpFeed::Service::MemberUpdater::ProfileFields::EXPERIENCE.join(',')}) SEPARATOR '--') from experiences where experiences.profile_answer_id = #{alias_name}.id), '') as '#{header}'"
    end

    def profile_question_column_select(header, question)
      alias_name = "profile_answers_#{question.id}"
      "COALESCE(#{alias_name}.answer_text, '') as '#{header}'"
    end

    def profile_question_column_join(header, question)
      alias_name = "profile_answers_#{question.id}"
      "LEFT JOIN profile_answers as #{alias_name} on #{alias_name}.ref_obj_id=members.id and #{alias_name}.ref_obj_type='Member' and #{alias_name}.profile_question_id=#{question.id} "
    end

    def location_column_select(header)
      "COALESCE(address_table.address_text, '') as '#{header}'"
    end

    def location_column_join
      "LEFT JOIN profile_answers as profile_answers_locations on profile_answers_locations.ref_obj_id=members.id and profile_answers_locations.ref_obj_type='Member' and profile_answers_locations.profile_question_id=#{@config.location_question(@headers).id} INNER JOIN (select answer_text as address_text,location_id from profile_answers where profile_question_id = #{@config.location_question(@headers).id} UNION select address_text,location_id from location_lookups) as address_table on address_table.location_id = profile_answers_locations.location_id"
    end

    def managers_column_select(header)
      "COALESCE(managers.#{manager_headers_hash[header]}, '') as '#{header}'"
    end

    def managers_column_join(manager_question)
      "LEFT JOIN profile_answers as profile_answers_managers on profile_answers_managers.ref_obj_id=members.id and profile_answers_managers.ref_obj_type='Member' and profile_answers_managers.profile_question_id=#{manager_question.id} LEFT JOIN managers on managers.profile_answer_id = profile_answers_managers.id"
    end

    def manager_headers_hash
      return {} unless @config.allow_manager_updates?(@headers)
      @config.supplement_questions_map[@config.manager_question(@headers).question_text].presence || {}
    end

    def members_column_select(header)
      "COALESCE(members.#{member_headers_hash[header]}, '') as '#{header}'"
    end

    def member_headers_hash
      {
        ChronusSftpFeed::Constant::FIRST_NAME => "first_name",
        ChronusSftpFeed::Constant::LAST_NAME => "last_name",
        ChronusSftpFeed::Constant::EMAIL => "email"
      }
    end

    def primary_column_select(header)
      "COALESCE(#{get_primary_key_db_column}, '') as '#{header}'"
    end

    def primary_column_join
      @config.use_login_identifier ? "LEFT JOIN login_identifiers ON login_identifiers.member_id = members.id AND auth_config_id = #{@config.custom_auth_config_ids.first}": ""
    end

    def get_primary_key_db_column
      @config.use_login_identifier ? "login_identifiers.identifier" : "members.email"
    end

    def delete_generated_files(files)
      files.each do |file|
        File.delete(file) if (file && File.exist?(file))
      end
    end
  end
end