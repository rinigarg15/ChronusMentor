class WidgetStyles < WidgetTag
  @widget_attributes = {
    uid:         '6v6ye9n', # rand(36**8).to_s(36)
    title:       Proc.new{"feature.email.widget_style.content.title".translate},
    description: Proc.new{"feature.email.widget_style.content.description".translate},
    plain_text:  true,
    super_admin: true,
    hide_tags:   true
  }

  register_tags do
  end

  def self.default_template(level = nil)
    "<style>\n</style>"
  end

  self.register!
end
