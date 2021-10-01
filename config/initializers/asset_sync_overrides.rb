# upload_file method is overridden because of the issue mentioned in https://github.com/AssetSync/asset_sync/issues/348
# This issue is fixed in 2.2.0. Please remove this file, while upgrading it to a version >= 2.2.0.

module AssetSync
  class Storage
    def upload_file(f)
      # TODO output files in debug logs as asset filename only.
      one_year = 31557600
      ext = File.extname(f)[1..-1]
      mime = MultiMime.lookup(ext)

      # --- OVERRIDE BEGIN ---

      # --- ORIGINAL CODE BEGIN ---

      #   file = {
      #   :key => f,
      #   :body => File.open("#{path}/#{f}"),
      #   :public => true,
      #   :content_type => mime
      #  }

      # --- ORIGINAL CODE END ---
      
      # --- OVERRIDE CODE BEGIN ---

      gzip_file_handle = nil
      file_handle = File.open("#{path}/#{f}")

      file = {
        :key => f,
        :body => file_handle,
        :public => true,
        :content_type => mime
      }

      # --- OVERRIDE CODE END ---

      # --- OVERRIDE END ---

      uncompressed_filename = f.sub(/\.gz\z/, '')
      basename = File.basename(uncompressed_filename, File.extname(uncompressed_filename))
      if /-[0-9a-fA-F]{32,}$/.match(basename)
        file.merge!({
          :cache_control => "public, max-age=#{one_year}",
          :expires => CGI.rfc1123_date(Time.now + one_year)
        })
      end

      # overwrite headers if applicable, you probably shouldn't specific key/body, but cache-control headers etc.

      if files_with_custom_headers.has_key? f
        file.merge! files_with_custom_headers[f]
        log "Overwriting #{f} with custom headers #{files_with_custom_headers[f].to_s}"
      elsif key = self.config.custom_headers.keys.detect {|k| f.match(Regexp.new(k))}
        headers = {}
        self.config.custom_headers[key].each do |k, value|
          headers[k.to_sym] = value
        end
        file.merge! headers
        log "Overwriting matching file #{f} with custom headers #{headers.to_s}"
      end


      gzipped = "#{path}/#{f}.gz"
      ignore = false

      if config.gzip? && File.extname(f) == ".gz"
        # Don't bother uploading gzipped assets if we are in gzip_compression mode
        # as we will overwrite file.css with file.css.gz if it exists.
        log "Ignoring: #{f}"
        ignore = true
      elsif config.gzip? && File.exist?(gzipped)
        original_size = File.size("#{path}/#{f}")
        gzipped_size = File.size(gzipped)

        if gzipped_size < original_size
          percentage = ((gzipped_size.to_f/original_size.to_f)*100).round(2)

          # --- OVERRIDE BEGIN ---

          # --- ORIGINAL CODE BEGIN ---

          # file.merge!({
          #               :key => f,
          #               :body => File.open(gzipped),
          #               :content_encoding => 'gzip'
          #             })

          # --- ORIGINAL CODE END ---
      
          # --- OVERRIDE CODE BEGIN ---

          gzip_file_handle = File.open(gzipped)

          file.merge!({
                        :key => f,
                        :body => gzip_file_handle,
                        :content_encoding => 'gzip'
                      })

          # --- OVERRIDE CODE END ---

          # --- OVERRIDE END ---

          log "Uploading: #{gzipped} in place of #{f} saving #{percentage}%"
        else
          percentage = ((original_size.to_f/gzipped_size.to_f)*100).round(2)
          log "Uploading: #{f} instead of #{gzipped} (compression increases this file by #{percentage}%)"
        end
      else
        if !config.gzip? && File.extname(f) == ".gz"
          # set content encoding for gzipped files this allows cloudfront to properly handle requests with Accept-Encoding
          # http://docs.amazonwebservices.com/AmazonCloudFront/latest/DeveloperGuide/ServingCompressedFiles.html
          uncompressed_filename = f[0..-4]
          ext = File.extname(uncompressed_filename)[1..-1]
          mime = MultiMime.lookup(ext)
          file.merge!({
            :content_type     => mime,
            :content_encoding => 'gzip'
          })
        end
        log "Uploading: #{f}"
      end

      if config.aws? && config.aws_rrs?
        file.merge!({
          :storage_class => 'REDUCED_REDUNDANCY'
        })
      end

      # --- OVERRIDE BEGIN ---

      # --- ORIGINAL CODE BEGIN ---

      # file = bucket.files.create( file ) unless ignore

      # --- ORIGINAL CODE END ---
      
      # --- OVERRIDE CODE BEGIN ---

      bucket.files.create( file ) unless ignore
      file_handle.close
      gzip_file_handle.close if gzip_file_handle

      # --- OVERRIDE CODE END ---

      # --- OVERRIDE END ---
    end
  end
end