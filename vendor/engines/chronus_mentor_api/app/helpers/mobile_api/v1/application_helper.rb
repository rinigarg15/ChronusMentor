module MobileApi::V1::ApplicationHelper

  # In order to support good quality image for retina device we need to render dobule size image.
  # Currently we only have four image sizes small(35X35), medium(50X50), large(75X75) and original.
  # Original is the largest size we have. Places where we need small image we are dsiplaying large 
  # but for medium and large we have to diplay original. This mapping needs to be changed when we 
  # will resize original to optimize the performance for medium and large.

  RETINA_IMAGE = {
    :very_small => :medium,
    :small => :large,
    :medium => :retina,
    :large => :retina
  }

  MOBILE_IMAGE = {
    :very_small => :small
  }

  def jbuilder_responder(json, defaults_params)
    ## TODO:: Refactor this. Tried to refactor this.
    ## Some understanding of the jBuilder gem is required to refactor this.
    json.defaults defaults_params[:defaults] if defaults_params[:defaults].present?
    json.theme defaults_params[:theme] if defaults_params[:theme].present?
    json.user_groups defaults_params[:user_groups] if defaults_params[:user_groups].present?
    json.group_features defaults_params[:group_features] if defaults_params[:group_features].present?
    json.page_controls_allowed defaults_params[:page_controls_allowed] unless defaults_params[:page_controls_allowed].nil?
    yield
  end

  def generate_member_url(member, options = {})
    size_sym = options[:size] || :medium
    image_options = member.present? ? member.picture_url(RETINA_IMAGE[size_sym], true) : ""
    image_with_initials = image_options[:image_with_initials] rescue false
    
    if !member.present? || options[:anonymous_or_default].present?
      image_src = MOBILE_IMAGE[size_sym] ? UserConstants::DEFAULT_PICTURE[MOBILE_IMAGE[size_sym]] : nil
      image_data = { image_src: image_src || UserConstants::DEFAULT_PICTURE[size_sym]}
    elsif image_with_initials
      image_data =  { 
        id: member.id, 
        initials: UnicodeUtils.upcase(member.first_name.try(:first).to_s + member.last_name.first)
      }
    else
      image_data = { image_src: image_options }
    end
    image_data.merge!(image_with_initials: image_with_initials, image_size: size_sym)
  end

  def generate_connection_url(group, acting_user, options = {})
    group_users = group.members
    size_sym = options[:size] || :medium
    url_hash = {image_with_initials: false, image_size: size_sym}
    if group.logo?
      url_hash.merge!(image_src: group.logo.url)
    elsif group_users.size == 2
      other_user = (group_users - [acting_user]).first
      url_hash = generate_member_url(other_user.member, options)
    else
      url_hash.merge!(image_src: group.logo_url)
    end
    url_hash
  end

  def datetime_to_string(date_time)
    ## Here we are using different formats for displaying date or datetime. Client will render it appropriately.
    date_time && date_time.strftime(date_time.is_a?(Date) ? 'time.formats.full_display_without_time'.translate : 'time.formats.full_display'.translate)
  end

  def tasks_meta_dictionary(group)
    # When the association is a arel, the array method .count, works differently. Hence using select method
    mentoring_model_tasks = group.mentoring_model_tasks
    {
      total_count: mentoring_model_tasks.size,
      overdue: mentoring_model_tasks.select(&:overdue?).size,
      completed: mentoring_model_tasks.select(&:done?).size,
      pending: mentoring_model_tasks.select(&:pending?).size
    }
  end
  
  def comments_list(json, comments)
    json.array! comments do |comment|
      json.id comment.id
      json.content comment.content
      if comment.attachment?
        json.attachment do
          json.file_name comment.attachment_file_name
          json.url comment.attachment.url
        end
      end
      json.image_url generate_member_url(comment.sender, size: :small)
      json.can_destroy current_member == comment.sender
      json.name comment.sender.name(name_only: true)
      json.created_at comment.created_at
    end
  end
end