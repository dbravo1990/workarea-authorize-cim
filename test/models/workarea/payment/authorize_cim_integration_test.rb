require 'test_helper'

if Workarea::VERSION::MAJOR == 3 && Workarea::VERSION::MINOR < 3
  module Workarea
    class AuthorizeCimIntegrationTest < Workarea::TestCase
      include AuthorizeCimGatewayVCRConfig

      def test_store_auth
        VCR.use_cassette 'authorize_net_cim/store_auth' do
          Payment::StoreCreditCard.new(tender).perform!

          tender.amount = 5.to_m
          transaction = tender.build_transaction(action: 'authorize')
          operation = Payment::Authorize::CreditCard.new(tender, transaction)
          operation.complete!
          assert(transaction.success?, 'expected transaction to be successful')
          transaction.save!

          assert(tender.token.present?)
        end
      end

      def test_store_purchase
        VCR.use_cassette 'authorize_net_cim/store_purchase' do
          Payment::StoreCreditCard.new(tender).perform!

          tender.amount = 5.to_m
          transaction = tender.build_transaction(action: 'purchase')
          operation = Payment::Purchase::CreditCard.new(tender, transaction)
          operation.complete!
          assert(transaction.success?)
          transaction.save!

          assert(tender.token.present?)
        end
      end

      def test_auth_capture
        VCR.use_cassette 'authorize_net_cim/auth_capture' do
          tender.amount = 5.to_m
          transaction = tender.build_transaction(action: 'authorize')
          operation = Payment::Authorize::CreditCard.new(tender, transaction)
          operation.complete!
          assert(transaction.success?)
          transaction.save!

          assert(tender.token.present?)

          capture = Payment::Capture.new(payment: payment)
          capture.allocate_amounts!(total: 5.to_m)
          assert(capture.valid?)
          capture.complete!

          capture_transaction = payment.transactions.detect(&:captures)
          assert(capture_transaction.valid?)
        end
      end

      def test_auth_void
        VCR.use_cassette 'authorize_net_cim/auth_void' do
          tender.amount = 5.to_m
          transaction = tender.build_transaction(action: 'authorize')
          operation = Payment::Authorize::CreditCard.new(tender, transaction)
          operation.complete!
          assert(transaction.success?, 'expected transaction to be successful')
          transaction.save!

          assert(tender.token.present?)

          operation.cancel!
          void = transaction.cancellation

          assert(void.success?)
        end
      end

      def test_purchase_void
        VCR.use_cassette 'authorize_net_cim/purchase_void' do
          tender.amount = 5.to_m
          transaction = tender.build_transaction(action: 'purchase')
          operation = Payment::Purchase::CreditCard.new(tender, transaction)
          operation.complete!
          assert(transaction.success?, 'expected transaction to be successful')
          transaction.save!

          assert(tender.token.present?)

          operation.cancel!
          void = transaction.cancellation

          assert(void.success?)
        end
      end

      private

        def gateway
          Workarea.config.gateways.credit_card
        end

        def payment
          @payment ||=
            begin
              profile = create_payment_profile
              create_payment(
                profile_id: profile.id,
                address: {
                  first_name: 'Ben',
                  last_name: 'Crouse',
                  street: '22 s. 3rd st.',
                  city: 'Philadelphia',
                  region: 'PA',
                  postal_code: '19106',
                  country: Country['US']
                }
              )
            end
        end

        def tender
          @tender ||=
            begin
              payment.set_address(first_name: 'Ben', last_name: 'Crouse')

              payment.build_credit_card(
                number: 4111111111111111,
                month: 1,
                year: Time.current.year + 1,
                cvv: 999
              )

              payment.credit_card
            end
        end
    end
  end
end
