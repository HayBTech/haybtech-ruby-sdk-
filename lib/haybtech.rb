# frozen_string_literal: true

require_relative 'haybtech/client'
require_relative 'haybtech/webhook'

module HayBTech
  class << self
    attr_accessor :shared_client

    def configure(secret_key = nil, options = {})
      @shared_client = Client.new(secret_key, options)
    end

    def client(secret_key = nil, options = {})
      return @shared_client if secret_key.nil?
      Client.new(secret_key, options)
    end

    def payments
      @shared_client ||= configure
      @shared_client.payments
    end

    def webhooks
      @shared_client ||= configure
      @shared_client.webhooks
    end

    def webhook
      Webhook
    end
  end
end
