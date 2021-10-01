require 'aws-sdk-v1'
require 'fileutils'
# USAGE: options which can be passed are  

#:url_expires, DECRIPTION " Sets the expiration time of the URL; after this time S3 will return an error if the URL is used; AN EXPIRATION DATE MORE THAN 7 DAYS OLD IS NOT SUPPORTED; To generate an URL without expiration use publicaccess.", DEFAULT = "1 day"
#:publicaccess, DESCRIPTION "Generates a public URL with no signature and no expiration date", DEFAULT = "false"
#:timestamp, Description "Embeds Timestamp to the filename"
#:file_name, Description "Name of the target file in S3"
#:use_ssl, Description "Whether to generate a secure (HTTPS) URL or a plain HTTP url", DEFAULT = "true"
#:content_type, Description "Type of the content stored", DEFAULT = "text/csv"
#:discard_source, Description "Delete the source file after transfer", DEFAULT = "true"

module ChronusS3Utils
  module S3Helper
    class << self
      def transfer(source_path, prefix, dest_bucket, options = {})
        options.reverse_merge!({discard_source: true})
        file = File.open(source_path, 'rb')
        file_name = options[:file_name] || get_file_name(source_path)
        file_name = embed_timestamp(file_name) if options[:timestamp]
        content_type = options[:content_type] || "text/csv"
        authenticate_s3
        key = prefix + "/" + file_name
        publicaccess = options[:publicaccess] || false
        accesscontrol =  publicaccess ? :public_read : :authenticated_read
        s3object = AWS::S3.new.buckets[dest_bucket].objects[key]
        begin
          s3object.write(file, acl: accesscontrol, content_disposition: "attachment: filename=#{file_name}", content_type: content_type)
          file.close
          File.delete(source_path) if options[:discard_source]
        rescue AWS::Errors::Base
        end
        get_object_link(dest_bucket, key, {:no_authentication => true, :expires => options[:url_expires], :use_ssl => options[:use_ssl], :publicaccess => options[:publicaccess]}) unless options[:skip_link_generation]
      end

      def get_object_link(bucket_name, key, options = {})
        use_ssl = options[:use_ssl] || true
        publicaccess = options[:publicaccess] || false
        authenticate_s3 unless options[:no_authentication]

        config_options = options[:region].present? ? { region: options[:region] } : {}
        s3object = AWS::S3.new(config_options).buckets[bucket_name].objects[key]
        # Expiration date greater than 7 days will throw an error. So making it to 7 days if its greater than 7.
        # Reference: http://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-query-string-auth.html
        (options[:expires] = 7.days) if options[:expires] && options[:expires].from_now > 7.days.from_now
        if s3object.exists?
          if publicaccess
            return s3object.public_url(secure: use_ssl).to_s
          else
            return s3object.url_for(:read, secure: use_ssl, expires: options[:expires] || 1.day).to_s
          end
        end
        return false
      end

      def delete_all(bucket_name, prefix, options = {})
        get_objects_with_prefix(bucket_name,prefix).each { |obj| obj.delete }
      end

      def delete(bucket_name, path)
        ChronusS3Utils::S3Helper.get_bucket(bucket_name).objects[path].delete
      end

      def authenticate_s3
        #For development and test environment - 
        AWS.config(:access_key_id => ENV["S3_KEY"], :secret_access_key => ENV["S3_SECRET"]) if (Rails.env.development? || Rails.env.test?)
        AWS.config(:region => S3_REGION)
        AWS.config(:s3_server_side_encryption => :aes256) if defined?(ENABLE_S3_SERVER_SIDE_ENCRYPTION) && ENABLE_S3_SERVER_SIDE_ENCRYPTION
      end

      def get_bucket(bucket_name)
        authenticate_s3
        AWS::S3.new.buckets[bucket_name]
      end

      def get_objects_with_prefix(bucket_name, prefix)
        get_bucket(bucket_name).objects.with_prefix(prefix)
      end

      def embed_timestamp(file_name)
        Time.now.utc.strftime('%Y%m%d%H%M%S') + "_" + file_name
      end

      def get_file_name(file_path)
        Pathname.new(file_path).basename.to_s
      end

      def write_to_file_and_store_in_s3(content, s3_prefix, options = {})
        file = Tempfile.new([options.delete(:file_name), options.delete(:file_extension) || ".txt"])
        file_name = File.basename(file.path)
        file.puts content
        file.close

        self.store_in_s3(file, s3_prefix, options)
        return file_name
      end

      def store_in_s3(file, s3_prefix, options = {})
        options.reverse_merge!(url_expires: 7.days, content_type: "text/plain", discard_source: true)
        self.transfer(file, s3_prefix, APP_CONFIG[:chronus_mentor_common_bucket], options)
      end
    end
  end
end