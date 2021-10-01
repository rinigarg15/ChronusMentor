module ApplicationEagerLoader

  def self.load(options = {})
    return if Rails.configuration.eager_load

    Rails.application.eager_load!
    return if options[:skip_engines]

    ::Rails::Engine.subclasses.map(&:instance).each(&:eager_load!)
  end
end