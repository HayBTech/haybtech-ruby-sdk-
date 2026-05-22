# frozen_string_literal: true

require 'openssl'
require 'json'

module HayBTech
  class SignatureError < Error; end

  class Webhook
    TOLERANCE = 300 # 5 minutes
    MAX_SIZE = 1_048_576 # 1MB

    def self.construct_event(payload, signature_header, secret)
      raise SignatureError, "Missing required parameters" if payload.nil? || signature_header.nil? || secret.nil?
      raise SignatureError, "Payload too large" if payload.bytesize > MAX_SIZE

      # Parse header: t=123,v1=abc
      parts = signature_header.split(',').each_with_object({}) do |chunk, hash|
        key, value = chunk.split('=', 2)
        hash[key.strip] = value.strip if key && value
      end

      raise SignatureError, "Malformed signature header" unless parts['t'] && parts['v1']

      timestamp = parts['t'].to_i
      received_sig = parts['v1']

      # Replay protection
      if (Time.now.to_i - timestamp).abs > TOLERANCE
        raise SignatureError, "Webhook signature expired (replay protection)"
      end

      # Compute expected signature
      signed_payload = "#{timestamp}.#{payload}"
      expected_sig = OpenSSL::HMAC.hexdigest('sha256', secret, signed_payload)

      # Constant-time comparison
      unless secure_compare(expected_sig, received_sig)
        raise SignatureError, "Invalid webhook signature"
      end

      begin
        JSON.parse(payload)
      rescue JSON::ParserError
        raise SignatureError, "Invalid JSON payload"
      end
    end

    private

    def self.secure_compare(a, b)
      return false if a.nil? || b.nil? || a.bytesize != b.bytesize
      
      # Use fixed_length_secure_compare if available (Ruby 2.7+)
      if OpenSSL.respond_to?(:fixed_length_secure_compare)
        OpenSSL.fixed_length_secure_compare(a, b)
      else
        # Fallback to double-HMAC for constant-time comparison
        l = a.bytesize
        res = 0
        b_bytes = b.bytes
        a.each_byte { |byte| res |= byte ^ b_bytes.shift }
        res == 0
      end
    end
  end
end
