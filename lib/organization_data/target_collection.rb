module OrganizationData
  class TargetCollection
    include OrganizationData::S3AssetsCollectionExtensions
    EMAIL_REGEX = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i
    EMAILS_TO_IGNORE = [SUPERADMIN_EMAIL]

    module OPERATION
      COLLECT_FOR_DELETE = "collect_for_delete"
      COLLECT_FOR_INSERT = "collect_for_insert"
      COLLECT_FOR_PROGRAM_DELETION = "collect_for_program_deletion"
      COLLECT_S3_ASSETS = "collect_s3_assets"
    end

    def initialize(model, ids, options={})
      @visited = {}
      @collect_errors = []
      @parent_ids = ids
      @parent_model = model.is_a?(String) ? model.constantize : model
      @parent_objects = @parent_model.where(:id=>@parent_ids)
      @collect_db_objects = {}
      @db_objects_collect_file_path = options[:db_file_path] || "#{Rails.root}/tmp/db_objects_#{@parent_ids}.json"
      @s3_asset_collect_file_path = options[:s3_asset_file_path] || "#{Rails.root}/tmp/s3_assets_#{@parent_ids}.csv"
      @operation = options[:operation]
    end

    def collect_data
      @is_program = (@parent_model == Program) && (@operation == OPERATION::COLLECT_FOR_PROGRAM_DELETION)
      @s3_asset_collect_csv = CSV.open(@s3_asset_collect_file_path, 'w')
      handle_special_cases if @parent_model == Organization
      collect_all_data
      handle_insert_global_collection if @operation == OPERATION::COLLECT_FOR_INSERT
      write_db_data_to_json
      @s3_asset_collect_csv.close
    end

    def get_errors
      errors = []
      errors << "Collect errors: #{@collect_errors}" if @collect_errors.present?
      return errors
    end

    private

    def handle_special_cases
      collect_article_contents
      collect_recieved_mails
      collect_abstract_program_children
    end

    def handle_insert_global_collection
      collect_locations
      collect_languages
      collect_features
      collect_permissions
      collect_tags
      collect_global_themes
      collect_object_permissions
    end

    def collect_languages
      store_objects(Language.pluck(:id), Language)
    end

    def collect_features
      store_objects(Feature.pluck(:id), Feature)
    end

    def collect_permissions
      store_objects(Permission.pluck(:id), Permission)
    end

    def collect_object_permissions
      store_objects(ObjectPermission.pluck(:id), ObjectPermission)
    end

    def self.get_dependent_associations_to_be_deleted(model, is_program = false)
      #Getting all the has_one and has_many associations with dependent destroy/delete_all relationships for program. Getting all the has_one and has_many associations with or without dependent destroy/delete_all for models other than program. Ignoring through and finder sql. Finder_sql is not related to any model. So, its not possible to delete it using this approach. It was used in two places in our codebase. And, they are already covered by other paths. So, skipping it now
      model.reflections.select{|_k,v| can_include_association?(v, is_program) && !v.options[:through] && !v.options[:finder_sql]}
    end

    def self.can_include_association?(association_info, is_program = false)
      return ([:has_one, :has_many].include?(association_info.try(:macro)) && [:destroy, :delete_all].include?(association_info.options[:dependent])) if is_program.present?
      ([:has_one, :has_many].include?(association_info.try(:macro)) || [:destroy, :delete_all].include?(association_info.options[:dependent]))
    end

    def self.get_uniq_key(data)
      Digest::SHA1.hexdigest(data)
    end

    def puts_args(*args)
      puts args
    end

    def print_collected_objects(ids_count, model)
      puts_args "Added Ids Count:#{ids_count} from #{model}"
    end

    def data_present_in_model?(model, ids)
      Array(ids).in_groups_of(5000) do |ids_group|
        return true if model.unscoped.exists?(:id => ids_group)
      end
      return false
    end

    def store_objects(ids, model)
      OrganizationData::S3AssetsCollectionExtensions.collect_s3_assets_for_model(model, ids, nil, @s3_asset_collect_csv)
      print_collected_objects(ids.size, model.to_s)
      @collect_db_objects[model.to_s] = (@collect_db_objects[model.to_s] || []) << ids
    end

    #Since, article content is root, we are collecting it manually and deleting it.
    def collect_article_contents
      article_content_ids = Article.where(:organization_id=>@parent_ids).pluck(:article_content_id)
      collect_all_data(ArticleContent,article_content_ids)
    end

    #Deleting all the abstract program children and their dependencies
    def collect_abstract_program_children
      program_ids = []
      @parent_objects.each{|obj| program_ids << obj.programs.pluck(:id)}
      abstract_program_ids = ((@parent_ids.is_a?(Array) ? @parent_ids : [@parent_ids]) + program_ids).flatten
      collect_all_children(AbstractProgram,abstract_program_ids)
    end

    #Removing all received mails of an organization by assuming that the from address will contain the member of that organization
    def collect_recieved_mails
      all_member_email_ids = Member.where(:organization_id => @parent_ids).pluck(:email) - EMAILS_TO_IGNORE
      mail_ids_to_be_deleted = ReceivedMail.select{|mail| all_member_email_ids.include?(mail.from_email.scan(EMAIL_REGEX).first)}.collect(&:id)
      store_objects(mail_ids_to_be_deleted,ReceivedMail)
    end

    def collect_locations
      profile_answers_with_location = ProfileAnswer.where.not(location_id: nil).pluck(:id)
      profile_answers_in_current_org = profile_answers_with_location & (@collect_db_objects["ProfileAnswer"] || []).flatten
      location_ids = ProfileAnswer.where(id: profile_answers_in_current_org).pluck(:location_id)
      store_objects(location_ids, Location)
    end

    def collect_tags
      tag_ids = ["User", "ArticleContent"].collect do |klass|
        ActsAsTaggableOn::Tagging.where(taggable_type: klass, taggable_id: (@collect_db_objects[klass] || []).flatten).pluck(:tag_id)
      end
      store_objects(tag_ids.flatten.uniq, ActsAsTaggableOn::Tag)
    end

    def collect_global_themes
      global_themes = Theme.where(program_id: nil)
      theme_ids = global_themes.where(id: (Organization.where(id: @parent_ids).pluck(:theme_id) + Program.where(parent_id: @parent_ids).pluck(:theme_id)).flatten).pluck(:id)
      store_objects(theme_ids, Theme)
    end

    def collect_all_children(parent_model, ids)
      return unless data_present_in_model?(parent_model, ids)
      associations = self.class.get_dependent_associations_to_be_deleted(parent_model, @is_program)
      return if associations.empty?
      parent_ids = ids
      associations.each do |association_key, association|
        begin
          ids_to_string = parent_ids.is_a?(Fixnum) ? parent_ids.to_s : parent_ids.join(',')
          #getting the hash of the visited node data(containing parent, association child and parent ids)
          uniqhash = self.class.get_uniq_key(parent_model.to_s + "=>" + association_key.to_s + ",ids=>" + ids_to_string)
          unless @visited[uniqhash]
            child_model = association.klass
            ids = get_object_ids_to_be_deleted(association, parent_ids, parent_model, child_model)
            @visited[uniqhash] = true
            collect_all_children(child_model, ids)
            store_objects(ids, child_model) unless ids.empty?
          end
        rescue => error
          @collect_errors << error.message
        end
      end
    end

    def collect_all_data(model = @parent_model, ids = @parent_ids)
      return unless data_present_in_model?(model, ids)
      collect_all_children(model, ids)
      store_objects(ids,model)
    end

    def write_db_data_to_json
      #removing duplicates and flattening it
      @collect_db_objects.each do |k,v|
        @collect_db_objects[k] = v.flatten.uniq
      end
      File.open(@db_objects_collect_file_path, 'w') do |f|
        f.write(@collect_db_objects.to_json)
      end
    end

    def get_objects_to_be_deleted_for_ratings(parent_model, child_model, objects_to_be_deleted)
      if child_model == Rating
        rateable_types =  if parent_model == User
                            ["QaQuestion", "QaAnswer"]
                          elsif parent_model == Member
                            ["Article", "Resource"]
                          end
        objects_to_be_deleted = objects_to_be_deleted.where(rateable_type: rateable_types) if rateable_types.present?
      end
      objects_to_be_deleted
    end

    def get_object_ids_to_be_deleted(association, parent_ids, parent_model, child_model)
      objects_to_be_deleted = child_model.unscoped.where(association.foreign_key.to_sym => parent_ids)
      objects_to_be_deleted = get_objects_to_be_deleted_for_ratings(parent_model, child_model, objects_to_be_deleted)
      #For polymorphic associations, we check if the type of the id also matches the parent model
      objects_to_be_deleted = objects_to_be_deleted.where("#{association.options[:as]}_type" => parent_model.to_s) if association.options[:as]
      objects_to_be_deleted.pluck(:id)
    end
  end
end
