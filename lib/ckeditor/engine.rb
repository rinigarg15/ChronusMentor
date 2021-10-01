module Ckeditor
  class Engine < ::Rails::Engine
    isolate_namespace Ckeditor

    config.to_prepare do
      Dir.glob(Rails.root + "app/decorators/ckeditor/**/*_decorator*.rb").each do |c|
        require_dependency(c)
      end
    end
  end
end