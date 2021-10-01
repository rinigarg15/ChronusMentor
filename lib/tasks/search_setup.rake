namespace :test do
  # Sets up the Elasticsearch search engine by indexing data in fixtures.
  desc "To set up the search engine for test environment"
  task(:search_setup) do
    RAILS_ENV = ENV['RAILS_ENV'] = "test"

    Rake::Task["db:fixtures:load"].invoke
    Rake::Task["es_indexes:full_indexing"].invoke
  end

  # Prepares matching engine for test database.
  desc "Prepares matching engine for running tests"
  task(:matching_setup) do
    RAILS_ENV = ENV['RAILS_ENV'] = "test"

    Rake::Task["matching:clear_and_full_index"].invoke
  end
end

desc "Elasticsearch search setup - Alias for test:search_setup"
task :tst do
  Rake::Task["test:search_setup"].invoke
  Rake::Task["test:matching_setup"].invoke
end