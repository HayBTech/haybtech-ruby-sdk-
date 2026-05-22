# frozen_string_literal: true

require 'net/http'
require 'json'
require 'openssl'
require 'securerandom'
require_relative 'resources/payments'
require_relative 'resources/webhooks'

module HayBTech
  class Error < StandardError; end
  class ApiError < Error
    attr_reader :status, :code, :data

    def __init__(message, status, code = nil, data = nil)
      super(message)
      @status = status
      @code = code
      @data = data
    end
  end

  class Client
    attr_reader :base_url, :timeout, :payments, :webhooks

    def initialize(secret_key = nil, options = {})
      secret_key ||= ENV['HAYBTECH_SECRET_KEY']
      raise Error, "Invalid secret key. Expected 'sk_live_...' or 'sk_test_...' or set HAYBTECH_SECRET_KEY environment variable." unless secret_key&.start_with?('sk_')
      
      # Prevent CRLF injection
      raise Error, "Invalid secret key: contains forbidden characters." if secret_key.match?(/[\r\n]/)

      @secret_key = secret_key
      @base_url = options[:base_url] || ENV['HAYBTECH_API_URL'] || 'https://api.haybtech.com/v1'
      @timeout = options[:timeout] || 15

      @payments = Resources::Payments.new(self)
      @webhooks = Resources::Webhooks.new(self)
    end

    def test_mode?
      @secret_key.start_with?('sk_test_')
    end

    # Security: Mask secret key in inspect
    def inspect
      "#<HayBTech::Client base_url=\"#{@base_url}\" test_mode=#{test_mode?} secret_key=\"sk_...#{@secret_key[-4..-1]}\">"
    end

    # Security: Prevent Marshalling of secret key
    def marshal_dump
      {
        base_url: @base_url,
        timeout: @timeout,
        secret_key: '********'
      }
    end

    def request(method, path, body = nil, extra_headers = {})
      url = URI.parse("#{@base_url.chomp('/')}/#{path.sub(%r{^/}, '')}")
      
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = (url.scheme == 'https')
      http.open_timeout = @timeout
      http.read_timeout = @timeout

      # Strict SSL verification
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      request_class = case method.to_s.upcase
                      when 'GET'    then Net::HTTP::Get
                      when 'POST'   then Net::HTTP::Post
                      when 'DELETE' then Net::HTTP::Delete
                      else raise Error, "Unsupported method: #{method}"
                      end

      req = request_class.new(url.request_uri)
      
      headers = {
        'Authorization' => "Bearer #{@secret_key}",
        'Accept'        => 'application/json',
        'Content-Type'  => 'application/json',
        'X-Request-ID'  => SecureRandom.uuid,
        'User-Agent'    => "HayBTech-Ruby-SDK/1.0.0 Ruby/#{RUBY_VERSION}"
      }
      headers.merge!(extra_headers)

      headers.each { |k, v| req[k] = v }
      req.body = body.to_json if body

      res = http.request(req)
      
      begin
        parsed = JSON.parse(res.body)
      rescue JSON::ParserError
        raise Error, "Invalid JSON response from HayBTech API: #{res.code}"
      end

      if res.code.to_i >= 400
        error = parsed['error'] || {}
        raise ApiError.new(
          error['message'] || 'Unknown API Error',
          res.code.to_i,
          error['code'],
          sanitize_response(parsed)
        )
      end

      parsed
    end

    private

    def sanitize_response(data)
      sensitive = %w[secret password token key pin cvv]
      
      sanitize = lambda do |obj|
        case obj
        when Hash
          obj.each_with_object({}) do |(k, v), h|
            h[k] = sensitive.include?(k.to_s.downcase) ? '********' : sanitize.call(v)
          end
        when Array
          obj.map { |v| sanitize.call(v) }
        else
          obj
        end
      end
      
      sanitize.call(data)
    end
  end
end
