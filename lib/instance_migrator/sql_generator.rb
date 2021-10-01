# InstanceMigrator::SqlGenerator.new("source", "target", "source_environment", "source_seed").generate

module InstanceMigrator
  class SqlGenerator
    attr_accessor :models, :domain, :source, :target, :tables, :source_seed, :source_environment
    COMMON_TABLES = {
      "features"    => "name",
      "permissions" => "name",
      "languages"   => "language_name",
      "tags" => "name",
      "themes" => "name",
      "object_permissions" => "name",
      "locations" => "full_address"
    }

    COMMON_TABLE_ASSOCIATION = {
      "organization_features"   => { "feature_id" => { table: "features" }},
      "role_permissions"        => { "permission_id" => { table: "permissions" }},
      "organization_languages"  => { "language_id" => { table: "languages" }},
      "member_languages"        => { "language_id" => { table: "languages" }},
      "programs"                => { "theme_id" => { table: "themes" }},
      "taggings"                => { "tag_id" => { table: "tags" }},
      "object_role_permissions" => { "object_permission_id" => { table: "object_permissions" }},
      "profile_answers"         => { "location_id" => { table: "locations" }},
      "location_lookups"        => { "location_id" => { table: "locations" }}
    }

    RATINGS_USER_ID_MAP = {
      "QaQuestion" => "users",
      "QaAnswer" => "users",
      "Article" => "members",
      "Resource" => "members"
    }

    MODELS_TO_IGNORE = ["Globalize::ActiveRecord::Translation", "Delayed::Backend::ActiveRecord::Job", "ActiveRecord::SessionStore::Session", "SimpleCaptcha::SimpleCaptchaData", "ActiveRecord::SchemaMigration", "ChronusDocs::AppDocument", "ChrRakeTasks", "CalendarSyncNotificationChannel", "SchedulingAccount", "CalendarSyncErrorCases", "CalendarSyncRsvpLogs", "PaperTrail::Version", "PaperTrail::VersionAssociation"]

    def initialize(source, target, source_environment, source_seed)
      self.source = source
      self.target = target
      self.tables = {}
      self.source_environment = source_environment
      self.source_seed = source_seed
    end

    def generate
      self.load_models!
      self.init_domain!
      self.populate_domain!
      self.generate_sql
    end

    def load_models!
      ApplicationEagerLoader.load
      self.models = ActiveRecord::Base.descendants
    end

    def init_domain!
      self.domain = new_hash
    end

    def init_model(model)
      self.domain[model.table_name] = new_hash if self.domain[model.table_name].blank?
    end

    def populate_domain!
      self.models.each {|model| populate_model(model)}
      new_models = ActiveRecord::Base.descendants[0..-1]
      (new_models - self.models).each {|model| populate_model(model)}
      cleanup_domain
      self.models = new_models
    end

    def cleanup_domain
      self.domain.each do |table, attributes|
        next if attributes.empty?
        attributes.each do |attribute, association|
          if association.is_a?(Array) && (association.size == 1 || association.collect(&:values).uniq.size == 1)
            self.domain[table][attribute] = association.first.values.first
          end
        end
      end
    end

    def populate_model(model)
      return if MODELS_TO_IGNORE.include?(model.name)
      init_model(model)
      table_name = model.table_name
      self.tables[model.name] = table_name
      model.reflections.values.each do |association|
        next if association.options[:through].present?
        v_table_name = get_table_name(association)
        init_domain_for_table(table_name, v_table_name)
        populate_foreign_keys(model, association, table_name, v_table_name)
      end
    end

    def populate_foreign_keys(model, association, table_name, v_table_name)
      if association.options[:as]
        self.domain[v_table_name][association.foreign_key] = {:polymorphic => "#{association.options[:as]}_type"}
      elsif association.options[:polymorphic]
        self.domain[table_name][association.foreign_key] = {:polymorphic => association.foreign_type}
      else
        handle_all_associations(model, association, table_name, v_table_name)
      end
    end

    def handle_all_associations(model, association, table_name, v_table_name)
      association_type = association.macro
      case association_type
      when :belongs_to
        handle_belongs_to(model, association, table_name, v_table_name)
      when :has_one
        self.domain[v_table_name][association.foreign_key] = table_name
      when :has_many
        self.domain[v_table_name][association.foreign_key] = table_name if association.options[:through].blank?
      when :has_and_belongs_to_many
        raise "Unhandled case"
      end
    end

    def handle_belongs_to(model, association, table_name, v_table_name)
      return if check_polymorphic_association_present_for_belongs_to_foreign_key?(association, table_name)
      if is_same_column_refers_two_models?(model, association, table_name)
        self.domain[table_name][association.foreign_key] << {model.name => v_table_name}
        self.domain[table_name][association.foreign_key].uniq!
      else
        handle_belongs_to_for_single_reference(model, association, table_name, v_table_name )
      end
    end

    def is_same_column_refers_two_models?(model, association, table_name)
      self.domain[table_name][association.foreign_key].present? && association.options[:class_name].present? && model.base_class != model && self.domain[table_name][association.foreign_key].is_a?(Array)
    end

    def check_polymorphic_association_present_for_belongs_to_foreign_key?(association, table_name)
      self.domain[table_name][association.foreign_key].present? && self.domain[table_name][association.foreign_key].is_a?(Hash) && self.domain[table_name][association.foreign_key]["polymorphic"].present?
    end

    def handle_belongs_to_for_single_reference(model, association, table_name, v_table_name )
      if association.options[:class_name].present? && model.base_class != model
        self.domain[table_name][association.foreign_key] = [{model.name => v_table_name}]
      else
        self.domain[table_name][association.foreign_key] = v_table_name
      end
    end

    def generate_sql
      File.open("#{Rails.root}/tmp/models.sql", 'w')  do |f|
        get_all_tables.each do |table|
          f.puts "SELECT target_max_id INTO @target_max_#{table}_id FROM #{self.target}.temp_model_table_map where table_name = '#{table}' LIMIT 1;"
          f.puts "SELECT source_max_id INTO @source_max_#{table}_id FROM #{self.target}.temp_model_table_map where table_name = '#{table}' LIMIT 1;"
        end
        write_generated_insert_statements_to_file(f, "!=")
      end
    end

    def write_generated_insert_statements_to_file(file_handler, operator)
      get_all_tables.each do |table|
        file_handler.puts "##-- Not in domain --##" unless self.domain.has_key?(table)
        condition = "#{self.source}.#{table}.id #{operator} @source_max_#{table}_id"
        insert_sql = generate_insert_sql_statement(table, condition)
        file_handler.puts insert_sql
      end
    end

    def generate_insert_sql_statement(table, condition)
      sql_string = "INSERT INTO #{self.target}.#{table} (%s) SELECT %s, CONCAT('#{self.source_environment}_#{self.source_seed}_', id) FROM #{self.source}.#{table} %s WHERE #{condition};"
      s_cols = []
      t_cols = []
      polymorphic_left_join = []
      common_tables_left_join = []

      self.get_cols_from(table).each do |column|
        col_string, polymorphic_left_join, common_tables_left_join = get_column_string(table, column, quoted_column_name(column), polymorphic_left_join, common_tables_left_join)

        s_cols << col_string

        t_cols << quoted_column_name(column)
      end
      t_cols << quoted_column_name(SOURCE_AUDIT_KEY)
      sprintf(sql_string, t_cols.join(', '), s_cols.join(', '), (polymorphic_left_join + common_tables_left_join).join(' '))
    end

    def get_column_string(table, column, col_string, polymorphic_left_join, common_tables_left_join)
      if self.domain[table] && self.domain[table][column]
        col_string, polymorphic_left_join, common_tables_left_join = get_query_key_for_column(table, column, polymorphic_left_join, common_tables_left_join)
      elsif column == "id"
        col_string = " id + @target_max_#{table}_id"
      end
      [col_string, polymorphic_left_join, common_tables_left_join]
    end

    def get_query_key_for_column(table, column, polymorphic_left_join, common_tables_left_join)
      col_string = quoted_column_name(column)
      if table == "ratings" && column == "user_id"
        col_string = get_misc_column_of_ratings(column)
      elsif self.domain[table][column].is_a?(Hash) && self.domain[table][column].has_key?(:polymorphic)
        col_string, polymorphic_left_join = get_polymorphic_association_column(table, column, polymorphic_left_join, col_string)
      elsif self.domain[table][column].is_a?(Array)
        col_string = get_misc_column(table, column)
      elsif COMMON_TABLE_ASSOCIATION[table].present? && COMMON_TABLE_ASSOCIATION[table].keys.include?(column)
        col_string, common_tables_left_join = get_common_tables_column(table, column, common_tables_left_join)
      else
        col_string = "IF(#{col_string} = 0 OR #{col_string} = NULL, #{col_string}, #{col_string} + @target_max_#{self.domain[table][column]}_id)"
      end
      return col_string, polymorphic_left_join, common_tables_left_join
    end

    def quoted_column_name(column)
      ActiveRecord::Base.connection.quote_column_name column
    end

    def get_all_tables
      self.tables.values.uniq
    end

    def get_cols_from(table)
      ActiveRecord::Base.connection.select_all("SHOW FIELDS FROM #{table}").rows.collect {|r| r[0]}.reject{|column_name| column_name == SOURCE_AUDIT_KEY}
    end

    def new_hash
      return ActiveSupport::HashWithIndifferentAccess.new
    end

    def get_table_name(association)
      association.options[:polymorphic] ? association.plural_name : association.table_name
    end

    def init_domain_for_table(table_name, v_table_name)
      self.domain[table_name] ||= new_hash
      self.domain[v_table_name] ||= new_hash
    end

    def get_misc_column_of_ratings(column)
      col_string = "CASE #{quoted_column_name('rateable_type')}"
      RATINGS_USER_ID_MAP.each do |model_table, mapped_table|
        col_string += " WHEN '#{model_table}' THEN #{column} + @target_max_#{mapped_table}_id"
      end
      col_string += " END"
    end

    def get_common_tables_column(table, column, common_tables_left_join)
      col_string = "j#{common_tables_left_join.size}.target_j_id"
      common_tables_left_join << "LEFT JOIN temp_common_join_table as j#{common_tables_left_join.size} ON j#{common_tables_left_join.size}.source_j_id = #{self.source}.#{table}.#{column} AND j#{common_tables_left_join.size}.table_name = '#{COMMON_TABLE_ASSOCIATION[table][column][:table]}'"
      [col_string, common_tables_left_join]
    end

    def get_polymorphic_association_column(table, column, polymorphic_left_join, col_string)
      if self.domain[table][column][:polymorphic].present?
        col_string += " + t#{polymorphic_left_join.size}.target_max_id"
        polymorphic_left_join << "LEFT JOIN temp_model_table_map as t#{polymorphic_left_join.size} ON #{self.source}.#{table}.#{self.domain[table][column][:polymorphic]} = t#{polymorphic_left_join.size}.model_name"
      end
      [col_string, polymorphic_left_join]
    end

    def get_misc_column(table, column)
      col_string = "CASE #{quoted_column_name('type')}"
      self.domain[table][column].each do |model_table|
        col_string += " WHEN '#{[model_table].first.sort.flatten[0]}' THEN #{column} + @target_max_#{[model_table].first.sort.flatten[1]}_id"
      end
      col_string += " END"
    end

    # Verfication of associations is done by printing the tables with their associations.
    # 
    # def print_report
    #   f = STDOUT
    #   File.open("#{Dir.home}/Desktop/models.txt", 'w')  do |f|
    #     self.models.each do |model|
    #       next if model.abstract_class?
    #       table_name = model.table_name
    #       next if self.tables.values.include?(table_name)
    #       self.tables[model.name] = table_name
    #       f.print "\n\ntable: #{table_name}"
    #       flag = true
    #       model.column_names.each do |column|
    #         # next unless column.to_s.ends_with?('_id')
    #         # next if self.domain[table_name][column]
    #         f.print "\n#{column}"
    #         assoc = self.domain[table_name][column]
    #         flag = false if assoc
    #         f.print "  ->  #{assoc}" if assoc
    #       end
    #       puts table_name if flag
    #     end
    #   end
    # end

  end
end