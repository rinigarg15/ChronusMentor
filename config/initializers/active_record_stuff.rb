module ActiveRecord
  class Base
    include ActsAsRateable
    include ActsAsSubscribable
    include ActsAsSummarizable
    include AuthorizationManager::ActsAsRoleBased
    include ChronusSanitization::HelperMethods
    include CustomAssociations::HasUnion
    include STIAttributeRestriction
    include ObjectRolePermissionExtension

    attr_accessor :updated_in_vulnerable_log, :allow_scrubber_to_destroy, :skip_delta_indexing

    class << self
      delegate :order_by_translated_field, to: :all
    end

    def save_without_timestamping!
      class << self
        def record_timestamps; false; end
      end

      save!

      class << self
        def record_timestamps; super ; end
      end
    end

    # Fetch recent records as defined in RecentEntriesLamda

    def self.recent(since, model = nil)
      model ||= self.table_name
      where(["#{model}.created_at > ?", since])
    end

    #Fetch partial records depending upon the offset and the limits
    def self.fetch_with_offset(per_page, offset, include_options)
      includes(include_options[:include] || {}).offset(offset).limit(per_page)
    end

    #
    # Registers a +before_save+ callback for sanitizing the attributes using
    # +sanitize_attribute+
    #
    def self.sanitize_html_attributes(*attrs)
      before_save do |record|
        attrs.each do |attr_name|
          record.sanitize_attribute(attr_name)
        end
      end
    end

    #
    # Sanitizes the attribute with name +attr_name+ by removing HTML comments
    # and other non-renderable content in it.
    #
    def sanitize_attribute(attr_name)
      attr = self.send(attr_name)

      # Return if attribute is nil.
      return if attr.nil?

      attr.gsub!(/<!\s*-\s*-.*-\s*-\s*>/, "")
      attr.gsub!(/&lt;?!\s*-\s*-.*-\s*-\s*&gt;?/, "")
    end

    def self.sanitize_attributes_content(*attrs)
      options = attrs.last.present? && attrs.last.is_a?(Hash) ? attrs.pop : {}
      options[:sanitize_scriptaccess] ||= []
      include ChronusSanitization::HelperMethods
      include SanitizeAllowScriptAccess
      has_many :vulnerable_content_logs, as: :ref_obj
      attr_accessor :sanitization_version, :current_member, :current_user

      before_save do |record|
        if can_sanitize?(record, options)
          attrs.each do |attr_name|
            original_content = record.send(attr_name)
            next if original_content.nil?
            sanitize_attr(record, attr_name, original_content, options)
          end
          record.updated_in_vulnerable_log = true
        end
        true
      end
    end

    def is_record_accessed_by_admin?
      self.current_user ? self.current_user.is_admin? : (self.current_member ? self.current_member.admin? : false)
    end

    def is_vulnerable_content_allowed_by_admin?
      member = self.current_member || self.current_user.member
      member ? member.organization.security_setting.allow_vulnerable_content_by_admin : false
    end

    # Overrides the callbacks whenever needed
    # Usage Eg:
    # Forum.without_callback(:do_stuff) do
    #   bla bla bla
    # end
    def self.without_callback(callback, &block)
      method = self.send(:instance_method, callback)
      self.send(:remove_method, callback)
      self.send(:define_method, callback) {true}
      yield
      self.send(:remove_method, callback)
      self.send(:define_method, callback, method)
    end

    # For will_paginate
    def self.per_page
      PER_PAGE
    end

    # The human name of classes. Override at model level as necessary
    # Eg. MentorRequest will be "Mentor requests" (tableize pluralizes the name)
    def self.human_name
      self.table_name.tableize.humanize
    end

    # MentorRequest => "Mentor Requests"
    def self.humanized_model_name
      self.model_name.human.pluralize
    end

    def transliterate_file_name
      # removing all charecters that are not alphabets or numbers or underscore or dot
      self.attachment_file_name.gsub!(/[^A-Za-z0-9 _ .]+/, '')
      self.attachment_file_name.strip!
      # replacing multiple spaces with an underscore
      self.attachment_file_name.gsub!(/\ +/, '_')
    end

    def get_attachment
      (TASK_COMMENT_STORAGE_OPTIONS[:storage] == :s3) ? AttachmentUtils.get_remote_data(self.attachment.url) : self.attachment
    end

    #strip the attribute of extra whitespace in the end/start
    def strip_whitespace_from(field)
      field.strip! if field
    end

    def get_valid_time_zone
      self.time_zone.presence || TimezoneConstants::DEFAULT_TIMEZONE
    end

    def short_time_zone
      DateTime.localize(ActiveSupport::TimeZone.new(self.get_valid_time_zone).tzinfo, format: :time_zone)
    end

    #
    # Registers a +before_save+ callback for making the ck editor assets embedded in the content to be publicly accessible.
    # Example: In role_question.rb, publicize_ckassets { assoc_name: :profile_question, attrs: [:help_text] }
    # When role question is made available for membership form (which is public), the assets in help_text attribute of profile question has to be publicized.
    #
    def self.publicize_ckassets(options = {})
      before_save do |record|
        if !defined?(record.publicly_accessible?) || record.publicly_accessible?
          record = record.send(options[:assoc_name]) if options[:assoc_name].present?
          options[:attrs].each do |attr|
            content = record.send(attr)
            if content.present?
              ck_asset_ids = content.scan(CK_ASSETS_REGEX).collect(&:first)
              Ckeditor::Asset.where(id: ck_asset_ids).update_all(login_required: false)
            end
          end
        end
      end
    end

    def self.get_eager_loadables_for_destroy
      required_macros = [:has_many, :has_one]
      self.reflect_on_all_associations.select do |association|
        (required_macros.include?(association.macro) && !association.options[:through] && association.options[:dependent].present?)
      end.collect(&:name)
    end

    def self.get_assoc_name_foreign_key_map
      self.reflect_on_all_associations.inject({}) do |assoc_name_foreign_key_map, association|
        if [:has_many, :has_one].include?(association.macro) && !association.options[:through]
          assoc_name_foreign_key_map[association.name] = association.foreign_key
        end
        assoc_name_foreign_key_map
      end
    end

    private

    def remove_comments(original_content)
      original_content =~ /<!--(.*?)-->[\n]?/m ? original_content.gsub(/<!--(.*?)-->[\n]?/m, "") : original_content
    end

    def sanitize_attr(record, attr_name, original_content, options)
      sanitized_content = chronus_sanitize(original_content, sanitization_version: record.sanitization_version)
      original_content = remove_comments(original_content)
      if ChronusSanitization::Utils.difference_detected?(original_content, sanitized_content)
        VulnerableContentLog.create!(original_content: original_content, sanitized_content: sanitized_content, member_id: record.current_member.id, ref_obj_column: attr_name.to_s, ref_obj_type: record.class.to_s, ref_obj_id: record.id) if !record.updated_in_vulnerable_log
        record[attr_name] = sanitized_content unless allow_vulnerable_content?(record)
      end
      record[attr_name] = sanitize_allowscriptaccess_in_media(record.send(attr_name)) if can_sanitize_script_access?(record, attr_name, options)
    end

    def can_sanitize_script_access?(record, attr_name, options)
      attr_name.in?(options[:sanitize_scriptaccess]) && (!allow_vulnerable_content?(record) || (record.sanitization_version == ChronusSanitization::HelperMethods::SANITIZATION_VERSION_V1))
    end

    def can_sanitize?(record, options)
      !(record.current_member.nil? && record.sanitization_version.nil?) && (options[:if].is_a?(Proc) ? options[:if].call(record) : true)
    end

    def allow_vulnerable_content?(record)
      record.is_record_accessed_by_admin? && record.is_vulnerable_content_allowed_by_admin?
    end

  end

  module Associations
    module ClassMethods
      #-------------------------------------------------------------------------
      # PROGRAM - ORGANIZATION RELATED ASSOCIATION HELPERS
      #-------------------------------------------------------------------------

      #
      # Defines a belongs_to association to a Program
      #
      def belongs_to_program(opts = {})
        assoc_opts =  {:class_name => 'Program',
                       :foreign_key => 'program_id'
                      }.merge(opts)

        belongs_to :program, assoc_opts
      end

      #
      # Defines a belongs_to association to a Program
      #
      def belongs_to_organization(opts = {})
        assoc_opts =  {:class_name => 'Organization',
                       :foreign_key => 'program_id'
                      }.merge(opts)

        belongs_to :organization, assoc_opts
      end

      #
      # Defines a generic belongs_to association with the name 'progam' that can
      # point either to a Program or an Organization
      #
      def belongs_to_program_or_organization(association_attr = :program, opts = {})
        assoc_opts =  {:class_name => 'AbstractProgram',
                       :foreign_key => 'program_id'
                      }.merge(opts)

        belongs_to association_attr, assoc_opts
      end

      #
      # Provides a named scope for filtering the records that are accessible to
      # a given organization member.
      #
      def acts_as_filterable_for_member(opts = {})
        filter_opts = {:foreign_key => 'program_id'}.merge(opts)

        scope :accessible_to, ->(member) {
          conditions_map = {filter_opts[:foreign_key] => member.active_programs}

          if filter_opts[:association]
            conditions_map = {filter_opts[:association][:table].to_sym => conditions_map}
            joins_info = filter_opts[:association][:name].to_sym
          end

          where(conditions_map).joins(joins_info)
        }
      end

      #-------------------------------------------------------------------------
      # ROLE RELATED
      #-------------------------------------------------------------------------

      role_mappings = {
          :mentor => RoleConstants::MENTOR_NAME,
          :student => RoleConstants::STUDENT_NAME,
          :admin => RoleConstants::ADMIN_NAME}

      role_mappings.each do |role_name, role_description|
        #
        # Defines a belongs_to relationship with the given options for associating
        # a user and registers a validation callback for making sure that
        # associated user is of the given role.
        #
        # belongs_to :student, :foreign_key => 'user_id', :class_name => 'User',
        #            :conditions => "area_count > 0", :counter_cache => true
        #
        define_method("belongs_to_#{role_name}_with_validations") do |*attrs|
          options = attrs.extract_options!
          association_key = attrs[0] || role_name

          default_options = {:foreign_key => 'user_id', :class_name => 'User'}
          should_validate_presence = options[:validate_presence].nil? ? true : options.delete(:validate_presence)

          belongs_to(association_key, default_options.merge(options))

          # validation to be defined for validating that the user being
          # associated with is of the right type.
          validate_role_method = "check_#{association_key}_is_#{role_name}"

          # Define the before_save callback that returns whether the associated
          # object (user) is of the right type
          define_method(validate_role_method) do
            if self.send(association_key) && !self.send(association_key).send("is_#{role_name}?")
              errors.add(association_key, "is not #{role_description}")
            end
          end

          if should_validate_presence
            validates_presence_of association_key
          end

          # Add validation callback
          validate validate_role_method.to_sym
        end

      end
    end
  end

  module Validations
    module ClassMethods
      # Validates that the specified attribute(user) has the permission
      #
      #   class Article < ActiveRecord::Base
      #     belongs_to :author, :class_name => 'User'
      #
      #     validates_permission_of :author, :write_article
      #   end
      #
      # The first attribute's value needs to be user object and the second argument needs to be permission. Both must not be blank
      def validates_permission_of(*attrs)
        permission_name = attrs.delete_at(1)

        configuration = {:on => :save}
        configuration.update(attrs.extract_options!)
        default_message = "does not have the permission to #{permission_name}"

        validates_each(attrs, configuration) do |record, attr_name, value|
          unless value && value.send("can_#{permission_name}?")
            record.errors.add(attr_name, (configuration[:message] || default_message))
          end
        end
      end
    end
  end
end


class ActiveRecord::Observer
  # Overrides the callbacks whenever needed
  # Usage Eg:
  # ForumObserver.without_callback(:do_stuff) do
  #   bla bla bla
  # end
  def self.without_callback(callback, &block)
    method = self.send(:instance_method, callback)
    self.send(:remove_method, callback)
    self.send(:define_method, callback) do |*args| true end
    yield
    self.send(:remove_method, callback)
    self.send(:define_method, callback, method)
  end
end

class ActiveRecord::Relation

  def order_by_translated_field(field, sort_direction = nil)
    sort_direction = CommonSortUtils::SORT_ASC if sort_direction.blank?
    is_translations_eager_loaded = (self.includes_values + self.eager_load_values).include? :translations
    sorted_ids = (is_translations_eager_loaded ? self : self.includes(:translations)).select("#{self.table_name}.id").sort_by(&field).map(&:id)
    return self if sorted_ids.blank?

    # Without Arel.sql, Relation.order_by_translated_field(:translated_attribute_name).last results in IrreversibleOrderError
    # https://github.com/rails/rails/pull/28191/files
    self.order(Arel.sql("FIELD(#{self.table_name}.id, #{sorted_ids.join(COMMA_SEPARATOR)})") => sort_direction)
  end
end