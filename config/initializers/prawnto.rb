require 'prawnto'

ActionView::Template.register_template_handler 'prawn', Prawnto::TemplateHandlers::Base
ActionView::Template.register_template_handler 'prawn_dsl', Prawnto::TemplateHandlers::Dsl
ActionView::Template.register_template_handler 'prawn_xxx', Prawnto::TemplateHandlers::Raw  

