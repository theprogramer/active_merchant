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
        options = {type: 'CreditCard'}.merge(options)
        post = {}
        add_invoice(post, {amount: money})
        add_payment(post, {card: payment, type: options[:type]})
        add_customer_data(post, payment, options)

        commit(:post, 'sales', post)
      end

      def authorize(money, payment, options={})
        options = {type: 'CreditCard'}.merge(options)
        post = {}
        add_invoice(post, {amount: money})
        add_payment(post, {card: payment, type: options[:type]})
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

      def add_invoice(post, options = {})
        options = {order_id: '2014111703', amount: 0, installments: 1}.merge(options)
        post['MerchantOrderId'] = options.dig :order_id
        post['Payment'] ||= {}
        post['Payment']['Amount'] = 1000
        post['Payment']['Installments'] = options.dig :installments
      end

      def add_payment(post, options = {})
        options = {descriptor: 'IIGD', card: {}, type: 'CreditCard'}.merge(options)
        post['Payment']['Type'] = options[:type]
        post['Payment']['ReturnUrl'] = 'http://app.ongrace.com/thanks/'
        post['Payment']['SoftDescriptor'] = options[:descriptor]
        post['Payment']['Authenticate'] = options[:type] == 'CreditCard' ? false : true
        post['Payment'][options[:type]] ||= {}
        post['Payment'][options[:type]]['CardNumber'] = options[:card].number
        post['Payment'][options[:type]]['Holder'] = options[:card].name
        post['Payment'][options[:type]]['ExpirationDate'] = "#{sprintf('%02d', options[:card].month)}/#{options[:card].year}"
        post['Payment'][options[:type]]['SecurityCode'] = options[:card].verification_value
        post['Payment'][options[:type]]['Brand'] = 'Visa'
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
