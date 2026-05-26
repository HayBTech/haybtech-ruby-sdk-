# HayBTech Ruby SDK

Official Ruby SDK for the HayBTech Payment Gateway API -- mobile payments across West Africa .

[![Gem Version](https://badge.fury.io/rb/haybtech-sdk.svg)](https://badge.fury.io/rb/haybtech-sdk)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D2.7-red.svg)](https://www.ruby-lang.org/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

---

## Installation

Add to your Gemfile:

```ruby
gem 'haybtech-sdk'
```

Then run:

```bash
bundle install
```

Or install directly:

```bash
gem install haybtech-sdk
```

---

## Quick Start (Zero-Config)

If you have `HAYBTECH_SECRET_KEY` set in your environment (e.g. via `.env`), you can use the SDK directly with zero configuration:

```ruby
require 'haybtech'

# Initiate a payment directly
begin
  response = HayBTech.payments.create({
    merchant_ref: 'ORDER-12345',
    amount: 5000,
    currency: 'XOF',
    success_url: 'https://mysite.com/success',
    failed_url: 'https://mysite.com/failed',
    callback_url: 'https://mysite.com/webhook'
  })

  puts "Payment URL: #{response.payment_url}"
  
  # Rails Helper
  # redirect_to response.payment_url
rescue HayBTech::Error => e
  puts "Error: #{e.message}"
end
```

---

## Webhooks (Rails)

Securely verify incoming webhooks:

```ruby
class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def receive
    payload = request.raw_post
    signature = request.headers['X-HayBTech-Signature']
    secret = ENV['HAYBTECH_WEBHOOK_SECRET']

    begin
      event = HayBTech.webhook.construct_event(payload, signature, secret)
      
      case event['event']
      when 'payment.success'
        order = Order.find_by(reference: event['data']['merchant_ref'])
        order.mark_as_paid!
      when 'payment.failed'
        # Handle failure
      when 'refund.success'
        # Process refund
      end
      
      head :ok
    rescue HayBTech::SignatureError => e
      render json: { error: e.message }, status: :forbidden
    end
  end
end
```

### Sinatra

```ruby
require 'sinatra'
require 'haybtech'

post '/webhook' do
  payload = request.body.read
  signature = request.env['HTTP_X_HAYBTECH_SIGNATURE']

  begin
    event = HayBTech.webhook.construct_event(payload, signature, 'whsec_...')
    
    if event['event'] == 'payment.success'
      # Mark order as paid
    end
    
    status 200
    'OK'
  rescue HayBTech::SignatureError
    status 403
    'Invalid Signature'
  end
end
```

---

## Available Events

| Event                     | Description              |
|:--------------------------|:-------------------------|
| `payment.success`         | Payment confirmed        |
| `payment.failed`          | Payment failed           |
| `payment.cancelled`       | Cancelled by customer    |
| `payment.expired`         | Payment timed out        |
| `payout.success`          | Payout completed         |
| `payout.failed`           | Payout failed            |
| `refund.success`          | Refund processed         |


---

## Error Handling

```ruby
begin
  response = HayBTech.payments.create(params)
rescue HayBTech::ApiError => e
  puts e.message      # Human-readable message
  puts e.http_status  # 400, 422, 500...
  puts e.code         # e.g., "insufficient_funds"
rescue HayBTech::Error => e
  # SDK not configured, key invalid, etc.
  puts e.message
end
```

---

## Test Mode

```ruby
HayBTech.configure('sk_test_...') # No real charges
```

---


---

## Security Features

This SDK is built for **Maximum Security**:

- **Zero Dependencies**: Uses only standard Ruby libraries (`net/http`, `openssl`). No vulnerabilities from external gems.
- **Secret Masking**: Keys are automatically masked in `inspect` and protected against `Marshal` serialization.
- **Memory Protection**: Webhook payloads are capped at 1 MB to prevent memory exhaustion attacks.
- **Timing Attack Resistance**: Uses `OpenSSL.fixed_length_secure_compare` for signature verification.
- **Replay Protection**: 5-minute timestamp tolerance on webhook signatures.
- **CRLF Guard**: Prevents HTTP header injection via malformed keys.

---

## API Resources

| Resource                  | Description                                     |
|:--------------------------|:------------------------------------------------|
| `HayBTech.payments`       | Create, retrieve, list, and verify transactions |
| `HayBTech.webhooks`       | Manage notification endpoints                   |
| `HayBTech.payouts`        | Create and track payouts                        |

| `HayBTech.webhook`        | Verify incoming webhook signatures              |

---

MIT License
# haybtech-ruby-sdk-
