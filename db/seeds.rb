# encoding: utf-8

def say_seeding(msg)
  newline
  print "*** Seeding #{msg}"
end

def newline
  print_and_flush("\n")
end

def dot
  print_and_flush(".")
end

def print_and_flush(msg)
  print msg
  $stdout.flush
end

say_seeding(Permission.name)
Permission.create_default_permissions

say_seeding(ObjectPermission.name)
ObjectPermission.create_default_permissions

say_seeding(Feature.name)
Feature.create_default_features

# We generate fixtures for Theme, Location and Language - so, seeds are not needed for them.
unless Rails.env.test?
  say_seeding(Theme.name)
  Theme.find_or_create_by(name: 'Default')

  say_seeding(Location.name)
  if Location.count.zero?
    RAILS_ENV = ENV['RAILS_ENV']
    Rake::Task["geo:populate"].invoke
  end

  say_seeding(Language.name)
  # Locales created here are disabled by default
  if Language.count.zero?
    Language.create!(title: 'Canadian French', display_title: 'Français canadien', language_name: 'fr-CA', enabled: false)
  end
end

# Done
newline
print "Done"
newline