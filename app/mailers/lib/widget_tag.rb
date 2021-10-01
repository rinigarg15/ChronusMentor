class WidgetTag < ActionMailer::Base # We are inheriting from Mailer just to have easy access to helper methods.
  helper ApplicationHelper
  helper ProgramsHelper
  helper UsersHelper
  helper UserMailerHelper
  include UserMailerHelper

  def self.get_descendants
    Dir[Rails.root.join("app/mailers/widgets/**").to_s].collect do |f|
      File.basename(f,'.rb').camelize.constantize
    end
  end

  def self.get_descendant(uid)
    get_descendants.find{|e| e.widget_attributes[:uid] == uid}
  end

  def initialize(mailer)
    mailer.instance_variables.each do |variable_name|
      instance_variable_set(variable_name, mailer.instance_variable_get(variable_name))
    end
  end

  def process(level)
    template        = self.class.get_template(@organization, @program, level)
    processed_tags  = process_tags_in_context(ChronusActionMailer::Base.get_tokens_from(template))
    Mustache.render(template, processed_tags).html_safe
  end

  def self.get_template(organization, program, level = nil)
    prog_template = self.prog_template(program) if program
    org_template = self.org_template(organization)

    level_template = prog_template.try(:source).present? ? prog_template : org_template
    
    level_template = (prog_template.try(:source).present? && level == EmailCustomization::Level::PROGRAM) ? prog_template : org_template if level.present?

    level_template.try(:source).presence || self.default_template(level)
  end

  def process_tags_in_context(tag_names)
    processed_tags = {}
    tag_names.each do|tag_name|
      processed_tags[tag_name.to_sym] = send(tag_name)
    end
    processed_tags.each{ |key,val| processed_tags[key] = h(val) }
    return processed_tags
  end

  attr_accessor :internal_attributes
  @widget_attributes = {}
  @@widget_uids = {}

  def widget_attributes
    self.class.widget_attributes
  end

  def self.widget_attributes
    @widget_attributes ||= self.class.instance_variable_get('widget_attributes')
  end

  def self.prog_template(prog)
    prog.mailer_widgets.find_by(uid: self.widget_attributes[:uid])
  end

  def self.org_template(org)
    org.mailer_widgets.find_by(uid: self.widget_attributes[:uid])
  end

  def self.register_tags(name = :specific_tags, &block)
    @tag_name = name
    widget_attributes[:tags] ||= {}
    widget_attributes[:tags][name] = {}
    block.call
  end

  def self.tag(name, details, &block)
    widget_attributes[:tags][@tag_name][name] = details
    raise "feature.email.error.description_missing".translate unless details.has_key?(:description)
    define_method(name, &block)
    helper do
      define_method(name, &block)
    end
  end

  def self.get_tags_from_widget
    tag_names =  ChronusActionMailer::Base.get_tokens_from(self.default_template).collect(&:to_sym)
    tag_names += ChronusActionMailer::Base.mailer_attributes[:tags][:global_tags].keys
    self.all_tags.slice(*tag_names)
  end

  def self.all_tags
    tags = self.widget_attributes[:tags][:specific_tags].dup
    ChronusActionMailer::Base.mailer_attributes[:tags].each do |_tag, values|
      tags.merge!(values)
    end
    return tags
  end

  Dir[Rails.root.join("app/mailers/tags/*.rb").to_s].each do |f|
    load f
  end

  def self.register!
    self.widget_attributes[:tags] ||= {}
    self.widget_attributes[:tags][:specific_tags] ||= {}
    self.set_widget_name
    self.register_uid
  end

  def self.set_widget_name
    self.widget_attributes[:widget_name] = self.name.underscore
  end

  def self.register_uid
    uid = self.widget_attributes[:uid]
    widget_name = self.widget_attributes[:widget_name]
    raise "feature.email.error.duplicate_uid".translate if @@widget_uids.keys.include?(uid) && @@widget_uids[uid] != widget_name
    @@widget_uids[uid] = widget_name
  end
end