# frozen_string_literal: true

module HayBTech
  module Resources
    class Payments
      def initialize(client)
        @client = client
      end

      def create(params, idempotency_key: nil)
        headers = idempotency_key ? { 'Idempotency-Key' => idempotency_key } : {}
        response = @client.request(:post, 'payments', params, headers)
        
        # Add helper for Rails redirection
        # usage: redirect_to HayBTech.payments.create(...).payment_url
        def response.payment_url
          self.dig('data', 'payment_url')
        end
        
        def response.successful?
          true # Since we didn't raise an error
        end
        
        response
      end

      def retrieve(id)
        @client.request(:get, "payments/#{id}")
      end

      def list(params = {})
        path = 'payments'
        path += "?#{URI.encode_www_form(params)}" unless params.empty?
        @client.request(:get, path)
      end

      def verify(id)
        @client.request(:post, "payments/#{id}/verify")
      end
    end
  end
end
