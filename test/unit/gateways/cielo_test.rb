require 'test_helper'

class CieloTest < Test::Unit::TestCase
  def setup
    @gateway = CieloGateway.new(
      merchant_id: 'merchant_key',
      merchant_key: 'merchant_key'
    )
    @credit_card = credit_card

    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'REPLACE', response.authorization
    assert response.test?
  end

  # def test_failed_purchase
  #   @gateway.expects(:ssl_post).returns(failed_purchase_response)

  #   @credit_card.number = '0000000000000002'

  #   response = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_failure response
  #   assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  # end

  # def test_successful_authorize
  # end

  # def test_failed_authorize
  # end

  # def test_successful_capture
  # end

  # def test_failed_capture
  # end

  # def test_successful_refund
  # end

  # def test_failed_refund
  # end

  # def test_successful_void
  # end

  # def test_failed_void
  # end

  # def test_successful_verify
  # end

  # def test_successful_verify_with_failed_void
  # end

  # def test_failed_verify
  # end

  # # def test_scrub
  # #   assert @gateway.supports_scrubbing?
  # #   assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  # # end

  # private

  # # def pre_scrubbed
  # #   %q(
  # #     Run the remote tests for this gateway, and then put the contents of transcript.log here.
  # #   )
  # # end

  # # def post_scrubbed
  # #   %q(
  # #     Put the scrubbed contents of transcript.log here after implementing your scrubbing function.
  # #     Things to scrub:
  # #       - Credit card number
  # #       - CVV
  # #       - Sensitive authentication details
  # #   )
  # # end

  # def successful_purchase_response
  #   %(
  #     Easy to capture by setting the DEBUG_ACTIVE_MERCHANT environment variable
  #     to "true" when running remote tests:

  #     $ DEBUG_ACTIVE_MERCHANT=true ruby -Itest test/remote/gateways/remote_cielo_test.rb -n test_successful_purchase
  #   )
  # end

  # def failed_purchase_response
  # end

  # def successful_authorize_response
  # end

  # def failed_authorize_response
  # end

  # def successful_capture_response
  # end

  # def failed_capture_response
  # end

  # def successful_refund_response
  # end

  # def failed_refund_response
  # end

  # def successful_void_response
  # end

  # def failed_void_response
  # end
end