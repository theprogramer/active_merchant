require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CieloGateway < Gateway
      self.test_url = 'https://apisandbox.cieloecommerce.cielo.com.br/1/'
      self.live_url = 'https://api.cieloecommerce.cielo.com.br/1/'

      self.supported_countries = ['BR']
      self.default_currency = 'BRL'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'https://www.cielo.com.br/'
      self.display_name = 'Cielo'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :merchant_id, :merchant_key)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        # add_address(post, payment, options)
        add_customer_data(post, payment, options)

        commit(:post, 'sales', post)
      end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        # add_address(post, payment, options)
        add_customer_data(post, payment, options)

        commit(:post, 'sales', post)
      end

      def capture(money, authorization, options={})
        commit(:put, "sales/#{authorization}/capture?amount=#{money}", options)
      end

      def refund(money, authorization, options={})
        commit(:put, "sales/#{authorization}/void?amount=#{money}", options)
      end

      def void(money, authorization, options={})
        commit(:put, "sales/#{authorization}/void?amount=#{money}", options)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(100, r.authorization, options) }
        end
      end

      def supports_scrubbing?
        false
      end

      # def scrub(transcript)
      #   transcript
      # end

      private

      def add_customer_data(post, payment, options)
        post['Customer'] ||= {}
        post['Customer']['Name'] = payment.name
      end

      def add_address(post, creditcard, options)
      end

      def add_invoice(post, money, options)
        post['MerchantOrderId'] = '2014111703'
        post['Payment'] ||= {}
        post['Payment']['Type'] = 'CreditCard'
        post['Payment']['Amount'] = amount(money).to_i
        post['Payment']['Installments'] = 1
      end

      def add_payment(post, credit_card)
        post['Payment']['SoftDescriptor'] = '123456789ABCD'
        post['Payment']['CreditCard'] ||= {}
        post['Payment']['CreditCard']['CardNumber'] = credit_card.number
        post['Payment']['CreditCard']['Holder'] = credit_card.name
        post['Payment']['CreditCard']['ExpirationDate'] = "#{sprintf('%02d', credit_card.month)}/#{credit_card.year}"
        post['Payment']['CreditCard']['SecurityCode'] = credit_card.verification_value
        post['Payment']['CreditCard']['Brand'] = 'Visa'
      end

      def parse(body)
        JSON.parse(body)
      end

      def api_request(method, url, data)
        raw_response = nil
        begin
          post_data = method == :post ? data : nil
          raw_response = ssl_request(method, url, post_data, headers)
          response = parse(raw_response)
        rescue ResponseError => e
          response = { 'ReturnMessage'=> 'Not Authorized', body: e.response.body}
        rescue JSON::ParserError
          response = json_error(raw_response)
        end
        response
      end

      def commit(method, action, parameters)
        url = (test? ? test_url : live_url) + action
        response = api_request(method, url, post_data(action, parameters).to_json)
        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        response.dig('Payment', 'Status') == 1 ||
        [2, 10].include?(response['Status']) 
      end

      def message_from(response)
        response.dig('Payment', 'ReturnMessage') ||
        response['ReturnMessage']
      end

      def authorization_from(response)
        response.dig('Payment', 'PaymentId') ||
        response['AuthorizationCode']
      end

      def post_data(action, parameters = {})
        case action
        when 'sales'
          parameters
        else
          "Error: unknown action (#{action})"
        end
      end

      def error_code_from(response)
        unless success_from(response)
          # TODO: lookup error code for this response
        end
      end

      def headers
        {
          'Accept' => 'application/json',
          'Content-Type' => 'application/json',
          'User-Agent' => "Cielo/v3 ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
          'MerchantId' => options[:merchant_id],
          'MerchantKey' => options[:merchant_key]
        }
      end
    end
  end
end
