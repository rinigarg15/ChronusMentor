module MobileApi
  class CommonParameters
    include MobileApi::V1::ApplicationHelper
    attr_accessor :organization, :program, :member, :user, :controller

    def initialize(organization, member, program, user)
      @organization = organization
      @member = member
      @program = program
      @user = user
    end


    def build_hash(client_md5, controller)
      @controller = controller
      common_params = {}
      if should_regenerate_hash?(client_md5)
        server_attrs = generate_hash
        term_attrs = server_attrs.delete(:terms)
        common_params[:theme] = generate_custom_theme(server_attrs[:custom_theme_url])
        common_params[:defaults] = {}
        common_params[:defaults].merge!(server_attrs)
        common_params[:defaults].merge!(terms: term_attrs)
        common_params[:defaults].merge!(server_md5: server_digest)
      end
      common_params
    end

    def should_regenerate_hash?(client_md5)
      (organization_eligible? || program_eligible?) && (client_md5.blank? || client_md5 != server_digest)
    end

    def server_digest
      @digest_gen ||= secure_digest(generate_hash)
    end

    def generate_terms(controller)
      if @terms_hash.nil?
        @terms_hash = {}
        translatable_methods = controller.class.translated_methods
        translatable_methods.each do |translatable_key|
          @terms_hash.merge!(translatable_key => controller.send(translatable_key))
        end
      end
      @terms_hash
    end

    def generate_program_params
      if @default_program_params.nil?
        @default_program_params = {}

        @default_program_params.merge!({
          prog_id: @program.id,
          prog_name: @program.name,
          prog_root: @program.root,
          prog_description: @program.description,
          prog_contact_admin_label: @program.contact_admin_setting.try(:label_name),
          prog_contact_admin_url: @program.contact_admin_setting.try(:contact_url),
          prog_contact_admin_instruction: @program.contact_admin_setting.try(:content),
          prog_mentor_request_style: @program.mentor_request_style

        }) if @program.present?

        @default_program_params.merge!({
          user_id: @user.id,
          user_state: @user.state,
          user_roles: MobileApi::V1::BasePresenter::RolesMapping.aliased_names(@user.role_names),
        }) if @user.present?
      end
      @default_program_params
    end

    def generate_organization_params
      if @default_organization_params.nil?
        @default_organization_params = {}

        @default_organization_params.merge!({
          org_id: @organization.id,
          org_name: @organization.name,
          org_mobile_logo_url: @organization.mobile_logo_url
        }) if @organization.present?

        @default_organization_params.merge!({
          organization: {
            name: @organization.name,
            domain: @organization.chronus_default_domain.domain,
            subdomain: @organization.chronus_default_domain.subdomain,
            default_domain: @organization.domain,
            default_subdomain: @organization.subdomain,
            default_protocol: @organization.get_protocol + "://",
            language_settings_enabled: @organization.language_settings_enabled?
          }
        })


        @default_organization_params.merge!({
          member_id: @member.id,
          member_email: @member.email,
          member_first_name: @member.first_name,
          member_last_name: @member.last_name,
          member_name: @member.name(name_only: true),
          member_image_url: generate_member_url(@member),
        }) if @member.present?
      end
      @default_organization_params
    end

  private

    def secure_digest(attrs)
      Digest::MD5.hexdigest(attrs.values.join('--'))
    end

    def organization_eligible?
      @organization.present? || @member.present?
    end

    def program_eligible?
      @program.present? || @user.present?
    end

    def generate_hash
      common_attrs = {}
      common_attrs.merge!(generate_organization_params) if organization_eligible?
      common_attrs.merge!(generate_program_params) if program_eligible?
      common_attrs.merge!(terms: generate_terms(@controller)) if @organization.present? || @program.present?
      common_attrs.merge!(current_locale:  ((I18n.locale == :"fr-FR") ? :"fr-CA" : I18n.locale))
      common_attrs
    end
  end
end