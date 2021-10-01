module Authentication
  module ByPassword
    
    # Stuff directives into including module
    def self.included( recipient )
      recipient.extend( ModelClassMethods )
      recipient.class_eval do
        include ModelInstanceMethods
        
        # Virtual attribute for the unencrypted password
        attr_accessor :password
        validates_length_of       :password, :within => 6..40, :if => :password_required?
        validates_presence_of     :password,                   :if => :password_required?
        validates_presence_of     :password_confirmation,      :if => :password_required?
        validates_confirmation_of :password,                   :if => :password_required?
        before_save :encrypt_password
      end
    end # #included directives

    #
    # Class Methods
    #
    module ModelClassMethods
      # This provides a modest increased defense against a dictionary attack if
      # your db were ever compromised, but will invalidate existing passwords.
      # See the README and the file config/initializers/site_keys.rb
      #
      # It may not be obvious, but if you set REST_AUTH_SITE_KEY to nil and
      # REST_AUTH_DIGEST_STRETCHES to 1 you'll have backwards compatibility with
      # older versions of restful-authentication.
      def password_digest(password, salt, encryption_type)
        if encryption_type == Member::EncryptionType::INTERMEDIATE
          digest = sha1_sha2_digest(password, salt)
        elsif encryption_type == Member::EncryptionType::SHA2
          digest = sha2_digest(password, salt)
        else
          digest = sha1_digest(password, salt)
        end
        digest
      end

      def sha1_digest(password, salt)
        digest = REST_AUTH_SITE_KEY
        REST_AUTH_DIGEST_STRETCHES.times do
          digest = secure_digest(digest, salt, password, REST_AUTH_SITE_KEY)
        end
        digest
      end

      def sha2_digest(password, salt)
        digest = REST_AUTH_SITE_KEY
        REST_AUTH_DIGEST_STRETCHES.times do
          digest = secure_digest_sha2(digest, salt, password, REST_AUTH_SITE_KEY)
        end
        digest
      end

      def sha1_sha2_digest(password, salt)
        digest = sha1_digest(password, salt)
        sha2_digest(digest, salt)
      end      
    end # class methods

    #
    # Instance Methods
    #
    module ModelInstanceMethods
      
      # Encrypts the password with the user salt
      def encrypt(password)
        self.class.password_digest(password, salt, encryption_type)
      end
      
      def authenticated?(password)
        if crypted_password == encrypt(password)
          encrypt_with_sha2(password) unless encryption_type == Member::EncryptionType::SHA2
          true
        else
          false
        end
      end
      
      #
      # Changes in the crypted password generation should be reflected in lib/sales_demo/member_populator.rb
      #
      # before filter 
      def encrypt_password
        return if password.blank?
        self.salt = self.class.make_token if new_record?
        # New passwords either through new member or forgot password should be encrypted with sha2
        self.encryption_type = Member::EncryptionType::SHA2
        self.crypted_password = encrypt(password)
      end
      def password_required?
        crypted_password.blank? || !password.blank?
      end
    end # instance methods
  end
end
