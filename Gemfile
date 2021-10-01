source 'https://rubygems.org'
source 'https://rails-assets.org' do
  gem 'rails-assets-airbrake-js-client'
end

gem 'rails', '5.1.4'
gem 'rake', "11.3.0" # Keep this in sync with chef rake version
gem 'mysql2', '0.4.5'
gem 'rack-cors', :require => 'rack/cors'

# Bundle edge Rails instead:
# gem 'rails',     :git => 'git://github.com/rails/rails.git'

gem 'json', '1.8.6'
gem 'rack-accept'
gem 'font-awesome-rails', '4.7.0.2'
gem 'fastclick-rails'
gem 'bootstrap-sass', '~> 3.1.1.0'

# Gems used only for assets and not required
# in production environments by default.
gem 'sass-rails', '5.0.6'
gem 'sass', '3.4.22'
gem 'sprockets', '3.7.2'
gem 'uglifier', "3.0.3"
gem 'therubyracer', '0.12.2'
gem 'asset_sync', '1.2.1'
gem "timecop"

gem 'jquery-rails', '4.1.1'

gem 'dalli' # memcache-store is dependent on this gem

group :demo, :performance, :training do
  gem "populator", git: "https://github.com/norikt/populator.git"
  gem "faker", "1.1.2"
end

group :development, :test do
  gem 'byebug', '9.0.6'
  gem "ruby-prof"
  gem 'better_errors'
  gem 'binding_of_caller'
  gem "parallel_tests", '2.13.0'
end

group :development do
  gem "bullet"
  gem "ec2onrails"
  gem "capistrano", :git => "https://github.com/vpuzzella/capistrano.git", :branch => "vpuzzella-patch-1"
  gem "ipaddress"
  gem 'rb-inotify', '>= 0.8.8'
#  gem 'rails-erd'
  gem "letter_opener"
  gem "guard"
  gem 'guard-livereload'
  # gem 'rb-inotify', '~> 0.8.8'
  gem "yajl-ruby" # Just to optimize the guard perf
  gem "thin"
  gem 'meta_request', "0.5.0"
  gem 'web-console', '~> 2.0'
end

gem 'smarter_csv', '1.1.0'

group :test do
  gem 'minitest', '5.10.3'
  gem 'test-unit'
  gem "connection_pool", git: "https://github.com/mperham/connection_pool.git", require: false, ref: '971b0163290984b27aed785294421e387ca9d2a0'
  gem 'cucumber-rails', "1.5", :require => false
  gem "database_cleaner"
  gem 'email_spec'
  gem "mocha", "1.2.1", :require => false
  gem "headless"
  gem "capybara-webkit"
  gem 'capybara', '~> 2.18'
  gem 'selenium-webdriver', '~> 3.11'
  gem 'geckodriver-helper'
  gem "axe-matchers", "1.3.4"
  gem 'ripl-ripper'
  gem 'appium_capybara', '~> 1.4'
  gem 'appium_lib', '~> 9.10'
  gem 'simplecov', '~>0.9.0', :require => false
  gem 'simplecov-csv', :require => false
  gem 'simplecov-json', require: false
  gem "capybara-firebug"
  gem "solano", "1.31.4"
  gem 'pdf-inspector', :require => "pdf/inspector"
  gem 'capybara-screenshot' # TODO_CAPYBARA_SCREENSHOT_UPGRADE
  gem "exifr"
  gem "minitest-reporters"
  gem 'rails-controller-testing'
end

gem 'encoding_sampler'
gem "parallel", "1.10.0"
gem "hpricot"
gem "geokit", "1.10.0"
gem "geokit-rails", "2.2.0"
gem "mongo", "2.5.1"
gem 'mongo_ext'
gem "mongoid", "7.0.0"
gem 'nokogiri', "1.8.2"
gem 'will_paginate', "3.1.5"
gem 'prawn', "2.1.0"
gem 'prawn-table', "0.2.2"
gem 'RedCloth', "4.3.2"
gem 'right_http_connection', :git => 'https://github.com/taystack/right_http_connection.git'
gem 'rmagick', "2.16.0", :require => 'rmagick'
gem 'aasm', "4.11.1"
gem 'rubyzip'
gem 'premailer', '1.8.6'

gem 'newrelic_rpm'
gem 'airbrake', '~> 6.1'
gem 'airbrake-ruby', '2.3.1'
gem 'spreadsheet', "1.1.3"
gem 'recurrence', "1.3.0"
gem "optiflag"
gem "trollop", "2.1.2"
gem 'bson_ext'
gem 'daemons', "1.2.6"

gem 'delayed_job_active_record', "4.1.2"
gem 'delayed_job_web', "1.4.3"
gem 'ckeditor', "4.2.4"
gem 'diffy', "3.1.0"
# Using aws-sdk-v1 for supporting paperclip
gem 'aws-sdk-v1', "1.66.0"
gem 'paperclip', '~>5.2.1'
# https://github.com/mbleigh/acts-as-taggable-on/pull/887
gem 'acts-as-taggable-on', git: "https://github.com/Fodoj/acts-as-taggable-on", branch: "rails-5.2"
gem 'ancestry', '3.0.1'
gem 'net-ldap', "0.15.0"
gem 'jwt'

gem 'amazon-ecs', "2.5.0", :require => 'amazon/ecs'
gem 'routing-filter', '0.6.1'
gem 'rinku', "2.0.4", :require => 'rails_rinku' # For auto_link

gem 'prarupa' # Prarupa is plugin for Rails 3 that provides the textilize, textilize_without_paragraph and markdown helpers.
gem 'ri_cal', "0.8.8"
gem 'mustache', "1.0.3"
gem 'simple_form', "3.5.0"
gem "ruby-saml-mod", :path => File.join('vendor', 'gems'), :require => "onelogin/saml"

gem 'validates_email_format_of', "1.6.3"
gem "dotenv", "2.1.1"

gem 'acts_as_list', "0.9.11"
gem 'acts_as_redeemable', path: File.join('vendor', 'gems')

gem 'simple_captcha', git: 'https://github.com/galetahub/simple-captcha.git', ref: '2602bf19a63df25929960b5a7721a9d265281ec1'
gem 'negative_captcha', "0.5"

gem 'ejs'
gem 'wicked_pdf', "1.1.0"
#this doesnt not use SSL v3,  wkhtmltopdf 0.12.2
gem 'wkhtmltopdf-binary', git: 'https://github.com/zakird/wkhtmltopdf_binary_gem', ref: '8baf245ff55ce4dc15c68e679a63cbb988b7c9c5'
gem 'activerecord-import', '0.14.0'
gem 'paper_trail'
gem 'ice_cube', "0.11.3"

gem 'chronus_mentor_api', :path => 'vendor/engines/chronus_mentor_api'
gem 'chronus_translations', :path => 'vendor/engines/chronus_translations'
gem 'campaign_management', :path => 'vendor/engines/campaign_management'
gem 'sso_validator', :path => 'vendor/engines/sso_validator'
gem 'chronus_docs', :path => 'vendor/engines/chronus_docs'
gem 'mobile_v2', :path => 'vendor/engines/mobile_v2'
gem 'globalize', git: 'https://github.com/globalize/globalize', ref: '55c9c7a6d94f5707c3ff72a318498c8c125287b1'
gem 'activemodel-serializers-xml' # Globalize related
gem 'browser', '2.3.0'
gem 'remotipart', '1.3.1'

gem 'unicode_utils'

# This gem is required for lib/ops/user_mgmt_helpers.rb. Once the ops code is completely moved out, we can put this only under development
gem 'colorize', "0.8.1"
# highline gem is rquired for lib/tasks/op.rake
gem 'highline', "1.7.8"
gem 'safe_cookies', '0.2.1'
gem "domainatrix"
gem 'jbuilder', "2.6.3"
gem "houston", '2.2.3'
gem "commander", "4.4.3"
gem 'gcm', '~> 0.1.1'
gem 'html_to_plain_text'
gem "elasticsearch-model", git: "https://github.com/elastic/elasticsearch-rails", ref: "7815039c0f78ed0b9b896936875ee4d01855390e"
gem "elasticsearch-rails", git: "https://github.com/elastic/elasticsearch-rails", ref: "7815039c0f78ed0b9b896936875ee4d01855390e"
gem "elasticsearch", "6.0.3"
gem 'mailgun-ruby', "1.1.2"
gem 'split', "2.2.0", :require => 'split/dashboard'
gem 'redis-namespace', "1.5.2"
gem 'split-counters', "0.3.1", :require => ['split/counters', 'split/countersdashboard']
gem 'jquery-raty-rails', git: 'https://github.com/bmc/jquery-raty-rails', ref: 'd36753c77c9b825e6e2746c1c70c3b11b85b86cc'
gem 'jquery-minicolors-rails', '2.2.3.0'
gem 'gmail', '0.6.0'
gem 'aws-sdk'
gem 'css_splitter', '0.4.6'
gem 'jquery-placeholder-rails'
gem 'rails-observers', '0.1.5'
gem 'memoist'
gem 'activerecord-session_store', "1.1.0"
gem 'savon', '~> 2.11', '>= 2.11.1'
# alternative for counter cache -> https://github.com/rails/rails/pull/14849
gem 'counter_culture', "1.6.2"
gem 'tzinfo-data', '~> 1.2016', '>= 1.2016.9'
gem 'launchy'

gem 'responders', '~> 2.4.0'
gem 'google_drive', '2.1.1'
gem 'lhm', git: 'https://github.com/soundcloud/lhm.git', ref: '1209fe22ec7505c0d2566b6d9a1d53acda6307bc'
# All the requests to aws elasticsearch service should be signed. "faraday_middleware-aws-signers-v4" gem helps to achieve that.
gem "faraday_middleware-aws-signers-v4"
gem 'oauth2', '~> 1.4.0'
gem "google-api-client"
gem "icalendar"
# https://stackoverflow.com/a/16156479
gem 'utf8-cleaner'
