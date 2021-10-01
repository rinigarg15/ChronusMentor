require_relative './../../../test_helper'

class PhraseappUtilsTest < ActiveSupport::TestCase

  def setup
    super
    @content_develop_project_id = 'content_develop_project_id'
    @user_auth_token = 'user_auth_token'
    @production_project_id = 'production_project_id'
    @locale_path = "/test/fixtures/files/globalization/**/*.ym"
    @en_locale_id = "64f61f8d3d69e7102a3842ed0bca68dd"
    @fr_locale_id = "102992fe544d09ffab5dda2538c8aecd"
    @en_locale = {
                "id"=>"#{@en_locale_id}",
                "name"=>"en",
                "code"=>"en",
                "default"=>true,
                "main"=>false,
                "rtl"=>false,
                "plural_forms"=>["zero", "one", "other"],
                "created_at"=>"2013-04-18T11:53:50Z",
                "updated_at"=>"2013-04-25T15:27:14Z",
                "source_locale"=>nil
              }
    @fr_locale = {
                "id"=>"#{@fr_locale_id}",
                "name"=>"fr-CA",
                "code"=>"fr-CA",
                "default"=>false,
                "main"=>false,
                "rtl"=>false,
                "plural_forms"=>["zero", "one", "other"],
                "created_at"=>"2013-04-18T11:54:11Z",
                "updated_at"=>"2015-12-21T09:05:47Z",
                "source_locale"=>nil
              }
    @locales = {"en" => @en_locale, "fr" => @fr_locale}
  end

  def test_get_tag_info
    stub_tag_info

    Globalization::PhraseappUtils.expects(:system_call).with("curl 'https://api.phraseapp.com/api/v2/projects/#{@content_develop_project_id}/tags/tag_1' -u #{@user_auth_token}:").returns(@tag_infos["1"].to_json)
    assert_equal @tag_infos["1"], Globalization::PhraseappUtils.get_tag_info(@user_auth_token, @content_develop_project_id, "tag_1")
  end

  def test_untranslated_keys_in_local
    stub_supported_locales
    path = File.join(self.class.fixture_path, "files", "globalization", "**", "*.valid.ym")
    hash = Globalization::PhraseappUtils.untranslated_keys_in_local(@user_auth_token, @content_develop_project_id, path)
    assert_equal_unordered ["fr-CA"], hash.keys
    assert_equal_unordered hash["fr-CA"], ["feature.only_english_key"]
  end

  def test_fetch_untranslated_keys_missing_keys
    stub_supported_locales
    stub_translations({"#{@en_locale_id}" => "en.valid", "#{@fr_locale_id}" => "fr-CA.valid"})
    File.delete("/tmp/phrase.#{@en_locale_id}.yml") if File.exist?("/tmp/phrase.#{@en_locale_id}.yml")
    File.delete("/tmp/phrase.#{@fr_locale_id}.yml") if File.exist?("/tmp/phrase.#{@fr_locale_id}.yml")
    untranslated_hash = {}
    assert_raise RuntimeError, "1 translations are missing for the keys" do
      untranslated_hash = Globalization::PhraseappUtils.fetch_untranslated_keys(@user_auth_token, @content_develop_project_id, "#{Rails.root.to_s}#{@locale_path}", "phrase.*.ym")
    end
  end

  def test_fetch_untranslated_keys
    stub_supported_locales
    stub_translations({"#{@en_locale_id}" => "en.valid", "#{@fr_locale_id}" => "fr-CA.other"})
    File.delete("/tmp/phrase.#{@en_locale_id}.yml") if File.exist?("/tmp/phrase.#{@en_locale_id}.yml")
    File.delete("/tmp/phrase.#{@fr_locale_id}.yml") if File.exist?("/tmp/phrase.#{@fr_locale_id}.yml")
    untranslated_hash = Globalization::PhraseappUtils.fetch_untranslated_keys(@user_auth_token, @content_develop_project_id, "#{Rails.root.to_s}#{@locale_path}", "phrase.*.ym")
    assert_empty untranslated_hash["en"]
    assert_empty untranslated_hash["fr-CA"]
  end

  def test_fetch_keys_from_local
    keys_set = Globalization::PhraseappUtils.fetch_keys_from_local("#{Rails.root.to_s}#{@locale_path}", "phrase.*.ym")
    assert_equal_unordered ["feature.only_english_key", "feature.both_english_and_french_key"], keys_set
  end

  def test_fetch_keys_from_phrase
    stub_translations({"#{@en_locale_id}" => "en.valid", "#{@fr_locale_id}" => "fr-CA.valid"})
    File.delete("/tmp/phrase.#{@en_locale_id}.yml") if File.exist?("/tmp/phrase.#{@en_locale_id}.yml")
    File.delete("/tmp/phrase.#{@fr_locale_id}.yml") if File.exist?("/tmp/phrase.#{@fr_locale_id}.yml")
    keys_set = Globalization::PhraseappUtils.fetch_keys_from_phrase(@user_auth_token, @content_develop_project_id, @locales["en"])
    assert_equal_unordered ["feature.only_english_key", "feature.both_english_and_french_key"], keys_set

    keys_set = Globalization::PhraseappUtils.fetch_keys_from_phrase(@user_auth_token, @content_develop_project_id, @locales["fr"])
    assert_equal_unordered ["feature.only_french_key", "feature.both_english_and_french_key"], keys_set
  end

  def test_merge_locales_to_single_yaml
    output_path = "/tmp/single.yml"
    Globalization::PhraseappUtils.merge_locales_to_single_yaml(Rails.root.to_s+@locale_path, output_path)
    result = YAML.load(File.read(output_path))
    assert_equal_unordered ["en", "fr-CA"], result.keys
    assert_equal_unordered ["only_english_key", "both_english_and_french_key"], result["en"]["feature"].keys
    assert_equal_unordered ["only_french_key", "both_english_and_french_key", "only_english_key"], result["fr-CA"]["feature"].keys
  end

  def test_merge_locales_to_single_yaml_with_nested_keys_false
    output_path = "/tmp/single.yml"
    Globalization::PhraseappUtils.merge_locales_to_single_yaml(Rails.root.to_s+@locale_path, output_path, false)
    result = YAML.load(File.read(output_path))
    assert_equal_unordered ["en.feature.only_english_key", "en.feature.both_english_and_french_key", "fr-CA.feature.only_french_key", "fr-CA.feature.both_english_and_french_key", "fr-CA.feature.only_english_key"], result.keys
  end

  def test_unused_keys
    path = Rails.root.to_s+@locale_path
    keys_set = Globalization::PhraseappUtils.unused_keys(path, path)
    assert_empty keys_set[0]
    assert_empty keys_set[1]

    keys_set = Globalization::PhraseappUtils.unused_keys(path, Rails.root.to_s+"/test/fixtures/files/globalization/en.valid.ym")
    assert_empty keys_set[0]
    assert_empty keys_set[1]

    keys_set = Globalization::PhraseappUtils.unused_keys(Rails.root.to_s+"/test/fixtures/files/globalization/en.valid.ym", path)
    assert_equal_unordered ["fr-CA.feature.only_french_key", "fr-CA.feature.both_english_and_french_key", "fr-CA.feature.only_english_key"], keys_set[0]
    assert_empty keys_set[1]
  end

  def test_place_order
    github_email = "abs.xyz@chronus.com"
    stub_tag_info
    Timecop.freeze(Time.now) do
      tag = "abs_xyz_chronus_com_#{Time.now.strftime("%d_%m_%Y_%H_%M_%S")}"
      Globalization::PhraseappUtils.expects(:merge_locales_to_single_yaml).returns()
      Globalization::PhraseappUtils.expects(:push_translation_file).returns()
      Globalization::PhraseappUtils.expects(:sleep).with(15).once.returns()

      Globalization::PhraseappUtils.expects(:system_call).with("curl 'https://api.phraseapp.com/api/v2/projects/#{@content_develop_project_id}/tags/#{tag}' -u #{@user_auth_token}:").returns(@tag_infos["1"].to_json)
      Globalization::PhraseappUtils.expects(:create_and_confirm_order).with(@user_auth_token, @content_develop_project_id, [@fr_locale_id], tag)
      Globalization::PhraseappUtils.expects(:fetch_supported_locales_from_phrase).returns([@en_locale, @fr_locale])
      Globalization::PhraseappUtils.place_order(github_email, {content_develop_project_id: @content_develop_project_id, user_auth_token: @user_auth_token})
    end
  end

  # test to check scenario when phraseapp push fails
  def test_place_order_when_phraseapp_push_fails
    github_email = "abs.xyz@chronus.com"
    stub_tag_info
    Timecop.freeze(Time.now) do
      tag = "abs_xyz_chronus_com_#{Time.now.strftime("%d_%m_%Y_%H_%M_%S")}"
      Globalization::PhraseappUtils.expects(:merge_locales_to_single_yaml).returns()
      Globalization::PhraseappUtils.expects(:push_translation_file).returns()
      Globalization::PhraseappUtils.expects(:sleep).with(15).once.returns()

      Globalization::PhraseappUtils.expects(:fetch_supported_locales_from_phrase).returns([@en_locale, @fr_locale])
      Globalization::PhraseappUtils.expects(:system_call).with("curl 'https://api.phraseapp.com/api/v2/projects/#{@content_develop_project_id}/tags/#{tag}' -u #{@user_auth_token}:").returns("{\"message\":\"Not Found\",\"documentation_url\":\"https://phraseapp.com/docs/api/v2/\"}")

      exception = assert_raises(RuntimeError) { Globalization::PhraseappUtils.place_order(github_email, {content_develop_project_id: @content_develop_project_id, user_auth_token: @user_auth_token}) }
      assert_equal "Tag info not available", exception.message
    end
  end

  # test to check scenario when phraseapp push fails
  def test_place_order_when_no_new_key
    github_email = "abs.xyz@chronus.com"
    stub_tag_info
    Timecop.freeze(Time.now) do
      tag = "abs_xyz_chronus_com_#{Time.now.strftime("%d_%m_%Y_%H_%M_%S")}"
      Globalization::PhraseappUtils.expects(:merge_locales_to_single_yaml).returns()
      Globalization::PhraseappUtils.expects(:push_translation_file).returns()
      Globalization::PhraseappUtils.expects(:sleep).with(15).once.returns()

      Globalization::PhraseappUtils.expects(:system_call).with("curl 'https://api.phraseapp.com/api/v2/projects/#{@content_develop_project_id}/tags/#{tag}' -u #{@user_auth_token}:").returns(@tag_infos["2"].to_json)
      Globalization::PhraseappUtils.expects(:fetch_supported_locales_from_phrase).returns([@en_locale, @fr_locale])
      Globalization::PhraseappUtils.place_order(github_email, {content_develop_project_id: @content_develop_project_id, user_auth_token: @user_auth_token})
    end
  end

  def test_create_and_confirm_order_with_incorrect_locale
    stub_phrase_order
    order_options = '{"lsp":"gengo","source_locale_id":"64f61f8d3d69e7102a3842ed0bca68dd","translation_type":"standard","tag":"tag_1","styleguide_id":"5bd554099065b5d5","target_locale_ids":["102992fe544d09ffab5dda2538c8aecd"]}'
    Globalization::PhraseappUtils.expects(:fetch_supported_locales_from_phrase).returns([@en_locale, @fr_locale])
    Globalization::PhraseappUtils.expects(:system_call).with("curl 'https://api.phraseapp.com/api/v2/projects/#{@content_develop_project_id}/orders' -u #{@user_auth_token}: -X POST -d '#{order_options}' -H 'Content-Type: application/json'").returns("{\"message\":\"Validation failed\",\"errors\":[{\"resource\":\"GengoTranslationOrder\",\"field\":\"target_locales\",\"message\":\"Please choose at least one target locale\"},{\"resource\":\"GengoTranslationOrder\",\"field\":\"translation_type\",\"message\":\"can't be blank\"},{\"resource\":\"GengoTranslationOrder\",\"field\":\"total_amount_in_cents\",\"message\":\"couldn't be calculated.\"}]}")


    exception = assert_raises(RuntimeError) { Globalization::PhraseappUtils.create_and_confirm_order(@user_auth_token, @content_develop_project_id, ["102992fe544d09ffab5dda2538c8aecd"], "tag_1", {styleguide_code:"5bd554099065b5d5"}) }
    assert_match "Unable to place order with phraseapp", exception.message
  end

  def test_create_and_confirm_order_with_incorrect_tag
    stub_phrase_order
    @place_order_response["tag_name"] = nil

    order_options = '{"lsp":"gengo","source_locale_id":"64f61f8d3d69e7102a3842ed0bca68dd","translation_type":"standard","tag":"tag_3","styleguide_id":"5bd554099065b5d5","target_locale_ids":["102992fe544d09ffab5dda2538c8aecd"]}'
    Globalization::PhraseappUtils.expects(:fetch_supported_locales_from_phrase).returns([@en_locale, @fr_locale])
    Globalization::PhraseappUtils.expects(:system_call).with("curl 'https://api.phraseapp.com/api/v2/projects/#{@content_develop_project_id}/orders' -u #{@user_auth_token}: -X POST -d '#{order_options}' -H 'Content-Type: application/json'").returns(
        @place_order_response.to_json
      )

    exception = assert_raises(RuntimeError) { Globalization::PhraseappUtils.create_and_confirm_order(@user_auth_token, @content_develop_project_id, [@fr_locale_id], "tag_3", {styleguide_code:"5bd554099065b5d5"}) }
    assert_match "Unable to place order with phraseapp", exception.message
  end

  def test_create_and_confirm_order_success
    stub_phrase_order
    order_options = '{"lsp":"gengo","source_locale_id":"64f61f8d3d69e7102a3842ed0bca68dd","translation_type":"standard","tag":"tag_1","styleguide_id":"5bd554099065b5d5","target_locale_ids":["102992fe544d09ffab5dda2538c8aecd"]}'
    Globalization::PhraseappUtils.expects(:fetch_supported_locales_from_phrase).returns([@en_locale, @fr_locale])
    Globalization::PhraseappUtils.expects(:system_call).with("curl 'https://api.phraseapp.com/api/v2/projects/#{@content_develop_project_id}/orders' -u #{@user_auth_token}: -X POST -d '#{order_options}' -H 'Content-Type: application/json'").returns(
        @place_order_response.to_json
      )
    Globalization::PhraseappUtils.expects(:system_call).with("curl https://api.phraseapp.com/api/v2/projects/#{@content_develop_project_id}/orders/EF39BCC9/confirm -X PATCH -u #{@user_auth_token}:").returns(
        @confirm_order_response.to_json
      )
    assert_equal @confirm_order_response["id"], Globalization::PhraseappUtils.create_and_confirm_order(@user_auth_token, @content_develop_project_id, [@fr_locale_id], "tag_1", {styleguide_code:"5bd554099065b5d5"})
  end

  def test_sync_production_with_content_develop_and_push_to_s3
    Timecop.freeze(Time.now) do
      locales = {"#{@fr_locale_id}" => "fr-CA.valid"}
      @target_path = File.join(Rails.root.to_s, "tmp", "latest_phraseapp", (Time.now.to_i / ((24*60*60))).to_s)
      stub_supported_locales(2)
      stub_translations(locales)
      stub_phrase_push(locales)
      S3Helper.expects(:delete_all).with(APP_CONFIG[:chronus_mentor_common_bucket], Globalization::PhraseappUtils::DEPLOYMENT_FILES_LOCATION).returns("")
      S3Helper.expects(:transfer).with(@target_path+"/phrase.#{@fr_locale_id}.yml", Globalization::PhraseappUtils::DEPLOYMENT_FILES_LOCATION, APP_CONFIG[:chronus_mentor_common_bucket]).returns("")
      Globalization::PhraseappUtils.sync_production_with_content_develop_and_push_to_s3({source_project_id: @content_develop_project_id, target_project_id: @content_develop_project_id, user_auth_token: @user_auth_token})
    end
  end

  def test_sync_production_with_content_develop_and_push_to_s3_error_case
    Timecop.freeze(Time.now) do
      locales = {"#{@fr_locale_id}" => "fr-CA.valid"}
      @target_path = File.join(Rails.root.to_s, "tmp", "latest_phraseapp", (Time.now.to_i / ((24*60*60))).to_s)
      stub_supported_locales(2)
      stub_translations(locales)
      stub_phrase_push(locales)
      S3Helper.expects(:delete_all).with(APP_CONFIG[:chronus_mentor_common_bucket], Globalization::PhraseappUtils::DEPLOYMENT_FILES_LOCATION).raises(RuntimeError, "No s3 connection error")
      error = assert_raise(RuntimeError) do
        Globalization::PhraseappUtils.sync_production_with_content_develop_and_push_to_s3({source_project_id: @content_develop_project_id, target_project_id: @content_develop_project_id, user_auth_token: @user_auth_token})
      end
      assert_equal "No s3 connection error", error.message
      assert_false File.exists?(@target_path)
    end
  end

  def test_pull_translations_from_s3_bucket_to_local
    filename = "phrase.language.yml"
    dummybucket = AWS::S3::Bucket.new("dummybucket")
    s3_obj_valid = AWS::S3::S3Object.new(dummybucket,"#{Globalization::PhraseappUtils::DEPLOYMENT_FILES_LOCATION}/#{filename}")
    s3_obj_invalid = AWS::S3::S3Object.new(dummybucket,"#{Globalization::PhraseappUtils::DEPLOYMENT_FILES_LOCATION}/my_language.yml")
    s3_obj_valid.expects(:read).returns("value_1")
    S3Helper.expects(:get_objects_with_prefix).with(APP_CONFIG[:chronus_mentor_common_bucket],Globalization::PhraseappUtils::DEPLOYMENT_FILES_LOCATION).returns([s3_obj_valid, s3_obj_invalid])
    path = File.join(Rails.root.to_s, "tmp")
    Globalization::PhraseappUtils.pull_translations_from_s3_bucket_to_local(path)
    assert_equal "value_1", File.read(File.join(Rails.root.to_s, "tmp", filename))
    assert_false File.exists?(File.join(Rails.root.to_s, "tmp", "my_language.yml"))
    File.delete(File.join(Rails.root.to_s, "tmp", filename))
  end

  def test_pull_translations_from_phrase_to_local
    stub_supported_locales
    stub_translations({"#{@fr_locale_id}" => "fr-CA.valid"})
    Globalization::PhraseappUtils.pull_translations_from_phrase_to_local("/tmp", "en", {project_id: @content_develop_project_id, user_auth_token: @user_auth_token})
    result = YAML.load(File.read("/tmp/phrase.#{@fr_locale_id}.yml"))
    assert_equal ["fr-CA"], result.keys
    assert_equal ["only_french_key", "both_english_and_french_key"], result["fr-CA"]["feature"].keys
  end

  def test_get_keys_having_corrupted_translations
    target_path = "#{Rails.root}/tmp/phraseapp/5678"
    Globalization::PhraseappUtils.expects(:rand).with(10000).returns(5678)
    Globalization::PhraseappUtils.expects(:pull_translations_from_phrase_to_local).with(target_path, true, {project_id: @content_develop_project_id, user_auth_token: @user_auth_token}).returns("")
    Globalization::PhraseappUtils.expects(:fetch_supported_locales_from_phrase).with(@user_auth_token, @content_develop_project_id).returns([@en_locale, @fr_locale])
    Globalization::PhraseappUtils.expects(:merge_locales_to_single_yaml).with(nil, "#{target_path}/phrase.en.yml").returns
    Globalization::PhraseappUtils.expects(:yaml_to_keys).with("#{target_path}/phrase.en.yml").returns({
      "key.one" => "This is {{key_one}} key one",
      "key.two" => "This is %{key_two} key two with {{two}} tags",
      "key.three" => "This is %{key_three} key three with %{two} tags",
      "key.four" => "This is {{key_four}} key four with {{two}} tags",
      "key.five" => "This is {{key_five}} key five",
      "key.six" => "<a href='chronus.com'> some text </a>",
      "key.seven" => "<a href='chronus.com'> some <b> text </b> </a>",
      "key.eight" => "<a href='chronus.com'> some <b> text </b> </a>",
      "key.nine" => "<a href='chronus.com'> some text </a>",
      "key.ten" => "<a href='chronus.com'> some text </a> <b> text </b>",
      "key.twelve" => ["1", "2", "3", "4"],
      "key.thirteen" => ["1", "2", "3", "4"]
    })
    Globalization::PhraseappUtils.expects(:yaml_to_keys).with("#{target_path}/phrase.#{@fr_locale_id}.yml", "fr-CA").returns({
      "key.one" => "This is {{key_one}} key one",
      "key.two" => "This is % {key_two} key two with {{two}} tags",
      "key.three" => "This is %{key_threee} key three with %{two} tags",
      "key.four" => "This is {{key_four} } key four with {{two}} tags",
      "key.five" => "This is {{key_fives}} key five",
      "key.six" => "<>a href='chronus.com'> some text </a>",
      "key.seven" => "<a href='chronus.com'> some <b> other </b> text </a>",
      "key.eight" => "<a href='other_chronus.com'> some <b> other </b> text </a>",
      "key.nine" => "<c href='chronus.com'> some text </c>",
      "key.ten" => "<b> text </b> <a href='chronus.com'> some text </a>",
      "key.eleven" => "only frence version",
      "key.twelve" => ["1", "2", "3", "4"],
      "key.thirteen" => ["1", "2", "3"]
    })
    problematic_keys = Globalization::PhraseappUtils.get_keys_having_corrupted_translations({project_id: @content_develop_project_id, user_auth_token: @user_auth_token})
    problematic_interpolation_keys = problematic_keys[:problematic_interpolation_keys]
    problematic_html_keys = problematic_keys[:problematic_html_keys]
    warning_html_keys = problematic_keys[:warning_html_keys]

    assert_equal 5, problematic_keys[:problematic_interpolation_keys].count
    assert_equal_hash problematic_interpolation_keys[0], {"key"=>"key.two", "en"=>"This is %{key_two} key two with {{two}} tags", "other"=>"This is % {key_two} key two with {{two}} tags", "locale"=>"fr-CA"}
    assert_equal_hash problematic_interpolation_keys[1], {"key"=>"key.three", "en"=>"This is %{key_three} key three with %{two} tags", "other"=>"This is %{key_threee} key three with %{two} tags", "locale"=>"fr-CA"}
    assert_equal_hash problematic_interpolation_keys[2], {"key"=>"key.four", "en"=>"This is {{key_four}} key four with {{two}} tags", "other"=>"This is {{key_four} } key four with {{two}} tags", "locale"=>"fr-CA"}
    assert_equal_hash problematic_interpolation_keys[3], {"key"=>"key.five", "en"=>"This is {{key_five}} key five", "other"=>"This is {{key_fives}} key five", "locale"=>"fr-CA"}
    assert_equal_hash problematic_interpolation_keys[4], {"key"=>"key.thirteen", "en"=>["1", "2", "3", "4"], "other"=>["1", "2", "3"], "locale"=>"fr-CA"}

    assert_equal 3, problematic_html_keys.count
    assert_equal_hash problematic_html_keys[0], {"key"=>"key.six", "en"=>"<a href='chronus.com'> some text </a>", "other"=>"<>a href='chronus.com'> some text </a>", "locale"=>"fr-CA"}
    assert_equal_hash problematic_html_keys[1], {"key"=>"key.eight",
     "en"=>"<a href='chronus.com'> some <b> text </b> </a>",
     "other"=>"<a href='other_chronus.com'> some <b> other </b> text </a>",
     "locale"=>"fr-CA"}

    assert_equal 0, warning_html_keys.count
  end

  def test_notify_untranslated_strings
    hash = {}
    Globalization::PhraseappUtils.expects(:untranslated_keys_in_local).returns(hash)
    assert_no_emails do
      Globalization::PhraseappUtils.notify_untranslated_strings
    end

    hash = {"fr-CA"=>["feature.only_english_key"]}
    Globalization::PhraseappUtils.expects(:untranslated_keys_in_local).returns(hash)
    assert_emails(1) do
      Globalization::PhraseappUtils.notify_untranslated_strings
    end
  end

  def test_notify_corrupted_translations
    hash = {problematic_interpolation_keys: [], problematic_html_keys: [], warning_html_keys: []}
    Globalization::PhraseappUtils.expects(:get_keys_having_corrupted_translations).returns(hash)
    assert_no_emails do
      Globalization::PhraseappUtils.notify_corrupted_translations
    end

    hash = {:problematic_interpolation_keys=>[{:key=>"key.two", :en=>"This is %{key_two} key two with {{two}} tags", :other=>"This is % {key_two} key two with {{two}} tags", :locale=>"fr-CA"}, {:key=>"key.three", :en=>"This is %{key_three} key three with %{two} tags", :other=>"This is %{key_threee} key three with %{two} tags", :locale=>"fr-CA"}, {:key=>"key.four", :en=>"This is {{key_four}} key four with {{two}} tags", :other=>"This is {{key_four} } key four with {{two}} tags", :locale=>"fr-CA"}, {:key=>"key.five", :en=>"This is {{key_five}} key five", :other=>"This is {{key_fives}} key five", :locale=>"fr-CA"}, {:key=>"key.thirteen", :en=>["1", "2", "3", "4"], :other=>["1", "2", "3"], :locale=>"fr-CA"}], :problematic_html_keys=>[{:key=>"key.six", :en=>"<a href='chronus.com'> some text </a>", :other=>"<<a href='chronus.com'> some text </a>", :locale=>"fr-CA"}, {:key=>"key.eight", :en=>"<a href='chronus.com'> some <b> text </b> </a>", :other=>"<a href='other_chronus.com'> some <b> other </b> text </a>", :locale=>"fr-CA"}, {:key=>"key.nine", :en=>"<a href='chronus.com'> some text </a>", :other=>"<c href='chronus.com'> some text </c>", :locale=>"fr-CA"}], :warning_html_keys=>[]}
    Globalization::PhraseappUtils.expects(:get_keys_having_corrupted_translations).returns(hash)
    assert_emails(1) do
      Globalization::PhraseappUtils.notify_corrupted_translations
    end
  end

  def test_backup_translations
    Timecop.freeze(Time.now) do
      time_now = (Time.now.to_i / ((24*60*60)))
      target_path = File.join(Rails.root.to_s, "tmp", "backup_phraseapp", time_now.to_s)
      output_path = "#{target_path}/#{Time.now.to_i.to_s}.yml"
      Globalization::PhraseappUtils.expects(:pull_translations_from_phrase_to_local).at_least(2).with(target_path, false, {project_id: APP_CONFIG[:phrase_backup_project_id]}).returns("")
      Globalization::PhraseappUtils.expects(:merge_locales_to_single_yaml).at_least(2).with(File.join(target_path, "**", "*.yml"), output_path, true, nil).returns
      ChronusS3Utils::S3Helper.stubs(:transfer).at_least(2).with(output_path, Globalization::PhraseappUtils::BACKUP_LOCATION, APP_CONFIG[:chronus_mentor_common_bucket], {url_expires: 2.minutes}).returns("")
      dummybucket = AWS::S3::Bucket.new("dummybucket")
      to_be_deleted_file_name = ((Time.now.to_i - 31.days) / ((24*60*60))).to_s
      s3_obj_to_be_delete = AWS::S3::S3Object.new(dummybucket, "#{Globalization::PhraseappUtils::BACKUP_LOCATION}/#{to_be_deleted_file_name}")
      s3_obj_valid = AWS::S3::S3Object.new(dummybucket, "#{Globalization::PhraseappUtils::BACKUP_LOCATION}/#{time_now.to_s}")
      S3Helper.expects(:get_objects_with_prefix).with(APP_CONFIG[:chronus_mentor_common_bucket], Globalization::PhraseappUtils::BACKUP_LOCATION).returns([s3_obj_valid])
      #To ensure delete is called, error is raised
      AWS::S3::S3Object.any_instance.stubs(:delete).raises(RuntimeError, "Object is deleted")
      assert_nothing_raised do
        Globalization::PhraseappUtils.backup_translations(target_path, output_path, time_now)
      end

      S3Helper.expects(:get_objects_with_prefix).with(APP_CONFIG[:chronus_mentor_common_bucket], Globalization::PhraseappUtils::BACKUP_LOCATION).returns([s3_obj_to_be_delete])
      error = assert_raise(RuntimeError) do
        Globalization::PhraseappUtils.backup_translations(target_path, output_path, time_now)
      end
      assert_equal "Object is deleted", error.message
    end
  end

  def test_notify_unused_keys
    unused_keys = []
    PhraseappKeysManagement::CodebaseParser.any_instance.expects(:get_unused_keys).returns(unused_keys)
    assert_no_emails do
      Globalization::PhraseappUtils.notify_unused_keys
    end

    unused_keys = ["feature.test.key"]
    PhraseappKeysManagement::CodebaseParser.any_instance.expects(:get_unused_keys).returns(unused_keys)
    assert_emails(1) do
      Globalization::PhraseappUtils.notify_unused_keys
    end
  end

  private

  def stub_supported_locales(count = 1)
    result = [@en_locale, @fr_locale]
    Globalization::PhraseappUtils.expects(:system_call).with("curl -sS 'https://api.phraseapp.com/api/v2/projects/#{@content_develop_project_id}/locales' -u #{@user_auth_token}:").times(count).returns(result.to_json)
  end

  def stub_translations(locales = {})
    locales.each_pair do |key, locale|
      locale = "phrase.#{locale}" unless key == @en_locale_id
      result = YAML.load(File.read("test/fixtures/files/globalization/#{locale}.ym"))
      Globalization::PhraseappUtils.expects(:system_call).with("curl -sS 'https://api.phraseapp.com/api/v2/projects/#{@content_develop_project_id}/locales/#{key}/download?file_format=yml' -u #{@user_auth_token}:").returns(result.to_yaml)
    end
  end

  def stub_phrase_push(locales)
    locales.each_pair do |key, locale|
      file_path = @target_path + "/phrase.#{key}.yml"
      Globalization::PhraseappUtils.expects(:system_call).with("curl -sS 'https://api.phraseapp.com/api/v2/projects/#{@content_develop_project_id}/uploads' -u #{@user_auth_token}: -X POST -F file=@#{file_path} -F locale_id=#{key}").returns({"success" => true})
    end
  end

  def stub_tag_info
    @tags = ["1" => "tag_1", "2" => "tag_2"]
    tag_1_info = {"name"=>"tag_1", "keys_count"=>1, "created_at"=>"2016-02-03T18:33:49Z", "updated_at"=>"2016-02-03T18:33:49Z",
      "statistics"=>[
        {"locale"=>{
          "id"=>"#{@en_locale_id}", "name"=>"en", "code"=>"en",
            "statistics"=>{
              "keys_total_count"=>1, "translations_completed_count"=>1, "translations_unverified_count"=>0, "keys_untranslated_count"=>0
            }
          }
        },
        {"locale"=>{
          "id"=>"#{@fr_locale_id}", "name"=>"fr-CA", "code"=>"fr-CA", "statistics"=>{
              "keys_total_count"=>1, "translations_completed_count"=>0, "translations_unverified_count"=>0, "keys_untranslated_count"=>1
            }
          }
        }
      ]
    }

    tag_2_info = {"name"=>"tag_2", "keys_count"=>0, "created_at"=>"2015-07-01T07:21:18Z", "updated_at"=>"2015-07-01T07:21:18Z",
      "statistics"=>[
        {"locale"=>{
          "id"=>"#{@en_locale_id}", "name"=>"en", "code"=>"en",
            "statistics"=>{
              "keys_total_count"=>0, "translations_completed_count"=>0, "translations_unverified_count"=>0, "keys_untranslated_count"=>0
            }
          }
        },
        {"locale"=>{
          "id"=>"#{@fr_locale_id}", "name"=>"fr-CA", "code"=>"fr-CA", "statistics"=>{
              "keys_total_count"=>0, "translations_completed_count"=>0, "translations_unverified_count"=>0, "keys_untranslated_count"=>0
            }
          }
        }
      ]
    }

    @tag_infos = {
      "1" => tag_1_info,
      "2" => tag_2_info
    }
  end

  def stub_phrase_order
    @styleguide_code = ENV['PHRASEAPP_STYLEGUIDE_CODE']
    @place_order_response = {
      "id"=>"EF39BCC9",
      "lsp"=>"gengo",
      "amount_in_cents"=>72,
      "currency"=>"usd",
      "message"=>nil,
      "state"=>"open",
      "translation_type"=>"standard",
      "progress_percent"=>0,
      "tag_name"=>"tag_1",
      "unverify_translations_upon_delivery"=>false,
      "quality"=>false,
      "priority"=>false,
      "created_at"=>"2016-02-04T10:25:37Z",
      "updated_at"=>"2016-02-04T10:25:38Z",
      "source_locale"=>{
        "id"=>"64f61f8d3d69e7102a3842ed0bca68dd", "name"=>"en", "code"=>"en"
      },
      "target_locales"=>[
        {
          "id"=>"102992fe544d09ffab5dda2538c8aecd",
          "name"=>"fr-CA",
          "code"=>"fr-FR"
        }
      ],
      "styleguide"=>{
        "id"=>"5bd554099065b5d5",
        "title"=>"Styleguide for translation of text with html content"
      }
    }

    @confirm_order_response = {
      "id"=>"EF39BCC9",
      "lsp"=>"gengo",
      "amount_in_cents"=>72,
      "currency"=>"usd",
      "message"=>nil,
      "state"=>"confirmed",
      "translation_type"=>"standard",
      "progress_percent"=>0,
      "tag_name"=>"tag_1",
      "unverify_translations_upon_delivery"=>false,
      "quality"=>false,
      "priority"=>false,
      "created_at"=>"2016-02-04T10:25:37Z",
      "updated_at"=>"2016-02-04T10:25:38Z",
      "source_locale"=>{
        "id"=>"64f61f8d3d69e7102a3842ed0bca68dd", "name"=>"en", "code"=>"en"
      },
      "target_locales"=>[
        {
          "id"=>"102992fe544d09ffab5dda2538c8aecd",
          "name"=>"fr-CA",
          "code"=>"fr-FR"
        }
      ],
      "styleguide"=>{
        "id"=>"5bd554099065b5d5",
        "title"=>"Styleguide for translation of text with html content"
      }
    }
  end
end
