# The contents of this file are subject to the terms
# of the Common Development and Distribution License
# (the License). You may not use this file except in
# compliance with the License.
#
# You can obtain a copy of the License at
# https://opensso.dev.java.net/public/CDDLv1.0.html or
# opensso/legal/CDDLv1.0.txt
# See the License for the specific language governing
# permission and limitations under the License.
#
# When distributing Covered Code, include this CDDL
# Header Notice in each file and include the License file
# at opensso/legal/CDDLv1.0.txt.
# If applicable, add the following below the CDDL Header,
# with the fields enclosed by brackets [] replaced by
# your own identifying information:
# "Portions Copyrighted [year] [name of copyright owner]"
#
# $Id: xml_sec.rb,v 1.6 2007/10/24 00:28:41 todddd Exp $
#
# Copyright 2007 Sun Microsystems Inc. All Rights Reserved
# Portions Copyrighted 2007 Todd W Saxton.

require 'rubygems'
require "xml/libxml"
require "openssl"
require "digest/sha1"
require "tempfile"
require "shellwords"

module XMLSecurity
  module SignedDocument
    attr_reader :validation_error

    def validate(idp_cert_fingerprint, idp_base64_cert, logger = nil)
      # get cert from response
      base64_cert_element = self.find_first("//ds:X509Certificate", Onelogin::NAMESPACES)
      if base64_cert_element.present?
        base64_cert = base64_cert_element.content
        cert_text = Base64.decode64(base64_cert)
        cert = OpenSSL::X509::Certificate.new(cert_text)

        # check cert matches registered idp cert
        fingerprint = Digest::SHA1.hexdigest(cert.to_der)
        expected_fingerprint = idp_cert_fingerprint.gsub(":", "").downcase
        if fingerprint != expected_fingerprint
          @validation_error = "Invalid fingerprint (expected #{expected_fingerprint}, got #{fingerprint})"
          return false
        end
      elsif idp_base64_cert.present?
        base64_cert = idp_base64_cert
      else
        @validation_error = "Certificate element missing in response (ds:X509Certificate) and not cert provided at settings"
        return false
      end

      validate_doc(base64_cert, logger)
    end

    def canonicalize_doc(doc, method, inclusive_namespaces = nil)
      # this is not robust enough, but a switch to libxmlsec replacing all
      # the hackery is imminent, so I'm not going to spend a lot of time on it.
      mode = 0; comments = false
      if method
        mode = 1 if method =~ %r{xml-exc-c14n}
        mode = 2 if method =~ %r{xml-c14n11}
        comments = method =~ %r{#withcomments}i
      end
      options = {:mode => mode, :comments => comments}
      options[:inclusive_ns_prefixes] = inclusive_namespaces unless inclusive_namespaces.blank?
      doc.canonicalize(options)
    end

    def canonicalize_node(node, method)
      tmp_document = LibXML::XML::Document.new
      tmp_document.root = tmp_document.import(node)
      canonicalize_doc(tmp_document, method)
    end

    def algorithm(element)
      algorithm = element["Algorithm"] if element
      algorithm = algorithm && algorithm =~ /sha(.*?)$/i && $1.to_i
      case algorithm
      when 256 then OpenSSL::Digest::SHA256
      when 384 then OpenSSL::Digest::SHA384
      when 512 then OpenSSL::Digest::SHA512
      else
        OpenSSL::Digest::SHA1
      end
    end

    def validate_doc(base64_cert, logger)
      # validate references
      sig_element = find_first("//ds:Signature", Onelogin::NAMESPACES)

      c14n_method = nil
      c14n_method_element = sig_element.find_first(".//ds:CanonicalizationMethod", Onelogin::NAMESPACES)
      if c14n_method_element
        c14n_method = c14n_method_element["Algorithm"]
      end

      inclusive_namespaces            = []
      inclusive_namespace_element     = self.find_first("//ec:InclusiveNamespaces", "ec" => c14n_method)

      if inclusive_namespace_element
        prefix_list                   = inclusive_namespace_element['PrefixList']
        inclusive_namespaces          = prefix_list.split(" ")
      end

      # check digests
      sig_element.find(".//ds:Reference", Onelogin::NAMESPACES).each do |ref|
        # Find the referenced element
        uri = ref["URI"]
        ref_element = find_first("//*[@ID='#{uri[1,uri.size]}']")

        # Create a copy document with it
        ref_document = LibXML::XML::Document.new
        ref_document.root = ref_document.import(ref_element)

        # Remove the Signature node
        ref_document_sig_element = ref_document.find_first(".//ds:Signature", Onelogin::NAMESPACES)
        ref_document_sig_element.remove! if ref_document_sig_element
        digest_algorithm = algorithm(ref.find_first(".//ds:DigestMethod", Onelogin::NAMESPACES))

        # Canonicalize the referenced element's document
        ref_document_canonicalized = canonicalize_doc(ref_document, c14n_method, inclusive_namespaces)
        hash = Base64::encode64(digest_algorithm.digest(ref_document_canonicalized)).chomp
        digest_value = sig_element.find_first(".//ds:DigestValue", Onelogin::NAMESPACES).content

        if hash != digest_value
          @validation_error = <<-EOF.gsub(/^\s+/, '')
            Invalid references digest.
            Got digest of
            #{hash}
            but expected
            #{digest_value}
            XML from response:
            #{ref_document.to_s(:indent => false)}
            Canonized XML:
            #{ref_document_canonicalized}
            EOF
          return false
        end
      end

      # verify signature
      signed_info_element = sig_element.find_first(".//ds:SignedInfo", Onelogin::NAMESPACES)
      canon_string = canonicalize_node(signed_info_element, c14n_method)

      base64_signature = sig_element.find_first(".//ds:SignatureValue", Onelogin::NAMESPACES).content
      signature = Base64.decode64(base64_signature)

      cert_text = Base64.decode64(base64_cert)
      cert = OpenSSL::X509::Certificate.new(cert_text)

      signature_algorithm = algorithm(signed_info_element.find_first(".//ds:SignatureMethod", Onelogin::NAMESPACES))
      if !cert.public_key.verify(signature_algorithm.new, signature, canon_string)
        @validation_error = "Invalid public key"
        return false
      end
      return true
    end

    def decrypt(settings)
      if settings.encryption_configured?
        find("//xenc:EncryptedData", Onelogin::NAMESPACES).each do |node|
          Tempfile.open("ruby-saml-decrypt") do |f|
            f.puts node.to_s
            f.close
            Tempfile.open("ruby-saml-privatekey-#{Time.now.to_i}.pem") do |privf|
              privf.puts settings.xmlsec_privatekey
              privf.close

              command = [ settings.xmlsec1_path, "decrypt", "--privkey-pem", privf.path]
              command += ["--pwd", settings.xmlsec_privatekey_pwd] if settings.xmlsec_privatekey_pwd.present?
              command << f.path
              decrypted_xml = %x{#{command.shelljoin}}
              if $?.exitstatus != 0
                @logger.warn "Could not decrypt: #{decrypted_xml}" if @logger
                return false
              else
                decrypted_doc = LibXML::XML::Document.string(decrypted_xml)
                decrypted_node = decrypted_doc.root
                decrypted_node = self.import(decrypted_node)
                node.parent.next = decrypted_node
                node.parent.remove!
              end
              privf.unlink
            end
            f.unlink
          end
        end
      end
      true
    end
  end
end
