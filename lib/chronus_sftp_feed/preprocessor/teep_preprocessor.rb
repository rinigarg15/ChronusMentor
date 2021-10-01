module ChronusSftpFeed
  module Preprocessor

    class TeepPreprocessor
      def self.pre_process(file, options = {})
        text = File.open(file, "r:ISO-8859-1").read.encode("UTF-8")
        import_file = Tempfile.new(["#{options[:organization_name]}_import", ".csv"])
        rows = text.split("\r\n")
        File.open(import_file, "w") do |writer|
          rows.each do |row|
            writer << row.gsub("\n", "").gsub("\u0092", "'")
            writer << "\n"
          end
        end
        import_file
      end
    end

  end
end