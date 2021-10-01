require 'shellwords'

module Paperclip
  class VirusScanner < Processor
    def initialize(file, options = {}, attachment = nil)
      super
      @file = file
      @current_format = File.extname(@file.path)
      @basename = File.basename(@file.path, @current_format)
      if options[:virus_test] && !ClamScanner.scan_file(file.path)
        raise VirusError, "virus present"
      end
    end

    def make
      Tempfile.new([@basename, @current_format].compact.join("."))
    end
  end
end