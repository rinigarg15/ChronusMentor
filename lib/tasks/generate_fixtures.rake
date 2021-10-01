require 'fileutils'

namespace :db do
  desc "Generates test fixture files"
  task generate_fixtures: :environment do
    if Rails.env.test?
      require Rails.root.to_s + '/test/lib/chronus_fixture_generator'
      require Rails.root.to_s + '/test/lib/career_dev/career_dev_fixture_generator'

      # Generate locale fixtures
      Globalization::PseudolocalizeUtils.pseudolocalize_for("#{Rails.root}/test/locales", ['de', 'es'])
      I18n.backend.load_translations

      # Clean the database first
      puts "*** FixturePopulator :: Cleaning the database"
      FileUtils.rm Dir.glob("test/fixtures/*.yml")
      Rake::Task["db:environment:set"].invoke
      Rake::Task["cleandb"].invoke

      # This is to bypass delayed job
      Object.send :alias_method, :send_later, :send

      print "*** FixturePopulator :: Generating data"
      @skip_es_delta_indexing = true
      Program.skip_match_report_admin_view_observer = true
      generator = ChronusFixtureGenerator.generate
      memory_objects = {
        models: generator.models,
        fixture_name_map: generator.fixture_name_map,
        object_map: generator.object_map,
        write_to_file: true
      }
      CareerDevFixtureGenerator.generate(memory_objects)
      Program.skip_match_report_admin_view_observer = false
      puts "\nDone"
    else
      system("bundle exec rake db:generate_fixtures RAILS_ENV=test")
    end
  end
end