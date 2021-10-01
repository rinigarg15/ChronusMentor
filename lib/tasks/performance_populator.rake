namespace :performance_populator do
  #Usage: bundle exec rake performance_populator:setup
  #More Info: Populate data for performance environment
  desc 'populator setup'
  task setup: :environment do
    SPEC_PATH = 'lib/populator_v3/config/spec_config.yml'
    screen_print = ENV['SCREEN']
    PopulatorTask.benchmark_wrapper "Populator" do
      PopulatorManager.new({:spec_file_path => SPEC_PATH, screen: screen_print}).populate
    end
    models_list = ChronusElasticsearch.models_with_es.map { |x| x.name}
    ElasticsearchReindexing.indexing_flipping_deleting(models_list)
  end

  #Usage: bundle exec rake performance_populator:integration_test
  #More Info: Used to test performance populator v3
  desc 'populator end to end test'
  task :integration_test => :environment do
    # Clean the database first.
    # Rake::Task["cleandb"].invoke
    print "*** PerformancePopulator :: Generating data ***"
    ActiveRecord::Base.descendants.each{|klass| klass.reset_column_information}
    PopulatorManagerIntegrationTest.new().test
  end
end