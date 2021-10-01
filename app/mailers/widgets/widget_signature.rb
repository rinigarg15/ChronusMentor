class WidgetSignature < WidgetTag
  @widget_attributes = {
    :uid          => 'm2pt6b0q', # rand(36**8).to_s(36)
    :title        => Proc.new{"feature.email.widget_signature.content.title".translate},
    :description  => Proc.new{|prog_or_org| "feature.email.widget_signature.content.description_v1".translate(prog_or_org.return_custom_term_hash)}
  }

  register_tags do
  end
  

  def self.default_template(level = nil)
    from_address = level == EmailCustomization::Level::ORGANIZATION ? "{{url_program}}" : "{{url_subprogram_or_program}}"
    from_name = level == EmailCustomization::Level::ORGANIZATION ? "{{program_name}}" : "{{subprogram_or_program_name}}"
  	"<div>" + 
    "feature.email.widget_signature.default_template.thanks".translate + 
    ", <br />
    <a href='#{from_address}' style ='text-decoration: none;color: #333333;'>#{from_name}</a>
    </div>"
  end

  self.register!
end