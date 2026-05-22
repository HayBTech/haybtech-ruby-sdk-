# frozen_string_literal: true

module HayBTech
  module Resources
    class Webhooks
      def initialize(client)
        @client = client
      end

      def all
        @client.request(:get, 'webhooks')
      end

      def create(params)
        @client.request(:post, 'webhooks', params)
      end

      def reveal(id, otp: nil)
        body = otp ? { otp: otp } : {}
        @client.request(:post, "webhooks/#{id}/reveal", body)
      end

      def rotate(id, otp: nil)
        body = otp ? { otp: otp } : {}
        @client.request(:post, "webhooks/#{id}/rotate", body)
      end

      def test(id)
        @client.request(:post, "webhooks/#{id}/test")
      end

      def delete(id, otp: nil)
        headers = otp ? { 'X-OTP' => otp } : {}
        @client.request(:delete, "webhooks/#{id}", nil, headers)
      end
    end
  end
end
