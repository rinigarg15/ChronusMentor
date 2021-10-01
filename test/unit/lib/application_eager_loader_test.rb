require_relative './../../test_helper.rb'

class ApplicationEagerLoaderTest < ActiveSupport::TestCase

  def test_load
    Rails.application.expects(:eager_load!).once
    Rails::Engine.any_instance.expects(:eager_load!).times(Rails::Engine.subclasses.size)
    Rails.configuration.stubs(:eager_load).returns(false)
    ApplicationEagerLoader.load
  end

  def test_load_when_skip_engines
    Rails.application.expects(:eager_load!).once
    Rails::Engine.any_instance.expects(:eager_load!).never
    Rails.configuration.stubs(:eager_load).returns(false)
    ApplicationEagerLoader.load(skip_engines: true)
  end

  def test_load_when_config_allows_eager_load
    Rails.application.expects(:eager_load!).never
    Rails::Engine.any_instance.expects(:eager_load!).never
    Rails.configuration.stubs(:eager_load).returns(true)
    ApplicationEagerLoader.load
  end
end