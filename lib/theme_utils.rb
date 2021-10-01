module ThemeUtils
  include ChronusS3Utils
  ASSETS_DIRECTORY = File.join(Rails.root, "tmp/cache/assets")
  WCAG_CLASSES_FILE_PATH = File.join(Rails.root, "app/assets/stylesheets/v3/generators/wcag_classes.scss")
  MANIFEST_FILE_PATH = File.join(Rails.root, "app/assets/stylesheets/v3/generators/manifest_v5.scss")

  def self.generate_theme(theme_colors_map, include_wcag_classes = false)
    theme_file_path = "/tmp/" + S3Helper.embed_timestamp("#{SecureRandom.hex(3)}_theme.css")

    begin
      variables_file_path = generate_scss_variables_file(theme_colors_map)
      template = get_template(variables_file_path, include_wcag_classes)
      FileUtils.mkdir_p(ASSETS_DIRECTORY, mode: 0777)
      expanded_body = ::Sass::Engine.new(template, syntax: :scss, cache: false, read_cache: false, style: :expanded, load_paths: ["#{Rails.root}/app/assets/stylesheets/v3"]).render
      File.open(theme_file_path, 'w') { |f| f.write(expanded_body) }
    rescue => ex
      raise ex
    ensure
      File.delete(variables_file_path) if File.exist?(variables_file_path)
    end
    theme_file_path
  end

  private

  def self.get_template(variables_file_path, include_wcag_classes)
    manifest_content = File.read(MANIFEST_FILE_PATH)
    variables = File.read(variables_file_path)
    total_content = manifest_content + variables
    return total_content unless include_wcag_classes

    total_content + File.read(WCAG_CLASSES_FILE_PATH)
  end

  def self.generate_scss_variables_file(theme_colors_map)
    variables_file_path = "/tmp/" + S3Helper.embed_timestamp("#{SecureRandom.hex(3)}_variables.scss")
    File.open(variables_file_path, 'w') do |file|
      ThemeBuilder::THEME_VARIABLES.keys.each do |element|
        color = theme_colors_map[element]
        file << "$#{element}: #{color};\n"
      end
      file << "@include v5-theme-color;\n"
    end
    variables_file_path
  end

end