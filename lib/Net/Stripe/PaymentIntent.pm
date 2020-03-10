package Net::Stripe::PaymentIntent;

use Moose;
use Moose::Util::TypeConstraints qw(enum);
use Kavorka;
extends 'Net::Stripe::Resource';

# ABSTRACT: represent an PaymentIntent object from Stripe

# Args for posting to PaymentIntent endpoints
has 'amount'                      => (is => 'ro', isa => 'Maybe[Int]');
has 'amount_to_capture'           => (is => 'ro', isa => 'Maybe[Int]');
has 'application_fee_amount'      => (is => 'ro', isa => 'Maybe[Int]');
has 'cancellation_reason'         => (is => 'ro', isa => 'Maybe[StripeCancellationReason]');
has 'capture_method'              => (is => 'ro', isa => 'Maybe[StripeCaptureMethod]');
has 'client_secret'               => (is => 'ro', isa => 'Maybe[Str]');
has 'confirm'                     => (is => 'ro', isa => 'Maybe[Bool]');
has 'confirmation_method'         => (is => 'ro', isa => 'Maybe[StripeConfirmationMethod]');
has 'currency'                    => (is => 'ro', isa => 'Maybe[Str]');
has 'customer'                    => (is => 'ro', isa => 'Maybe[StripeCustomerId]');
has 'description'                 => (is => 'ro', isa => 'Maybe[Str]');
has 'error_on_requires_action'    => (is => 'ro', isa => 'Maybe[Bool]');
has 'mandate'                     => (is => 'ro', isa => 'Maybe[Str]');
has 'mandate_data'                => (is => 'ro', isa => 'Maybe[HashRef]');
has 'metadata'                    => (is => 'ro', isa => 'Maybe[HashRef[Str]|EmptyStr]');
has 'off_session'                 => (is => 'ro', isa => 'Maybe[Bool]');
has 'on_behalf_of'                => (is => 'ro', isa => 'Maybe[Str]');
has 'payment_method'              => (is => 'ro', isa => 'Maybe[StripePaymentMethodId]');
has 'payment_method_options'      => (is => 'ro', isa => 'Maybe[HashRef]');
has 'payment_method_types'        => (is => 'ro', isa => 'Maybe[ArrayRef[StripePaymentMethodType]]');
has 'receipt_email'               => (is => 'ro', isa => 'Maybe[Str]');
has 'return_url'                  => (is => 'ro', isa => 'Maybe[Str]');
has 'save_payment_method'         => (is => 'ro', isa => 'Maybe[Bool]');
has 'setup_future_usage'          => (is => 'ro', isa => 'Maybe[Str]');
has 'shipping'                    => (is => 'ro', isa => 'Maybe[HashRef]');
has 'statement_descriptor'        => (is => 'ro', isa => 'Maybe[Str]');
has 'statement_descriptor_suffix' => (is => 'ro', isa => 'Maybe[Str]');
has 'transfer_data'               => (is => 'ro', isa => 'Maybe[HashRef]');
has 'transfer_group'              => (is => 'ro', isa => 'Maybe[Str]');
has 'use_stripe_sdk'              => (is => 'ro', isa => 'Maybe[Bool]');

# Args returned by the API
has 'id'                  => (is => 'ro', isa => 'StripePaymentIntentId');
has 'amount_capturable'   => (is => 'ro', isa => 'Int');
has 'amount_received'     => (is => 'ro', isa => 'Int');
has 'application'         => (is => 'ro', isa => 'Maybe[Str]');
has 'cancellation_reason' => (is => 'ro', isa => 'Maybe[StripeCancellationReason]');
has 'canceled_at'         => (is => 'ro', isa => 'Maybe[Int]');
has 'charges'             => (is => 'ro', isa => 'Net::Stripe::List');
has 'client_secret'       => (is => 'ro', isa => 'Maybe[Str]');
has 'created'             => (is => 'ro', isa => 'Int');
has 'invoice'             => (is => 'ro', isa => 'Maybe[Str]');
has 'last_payment_error'  => (is => 'ro', isa => 'Maybe[HashRef]');
has 'livemode'            => (is => 'ro', isa => 'Bool');
has 'next_action'         => (is => 'ro', isa => 'Maybe[HashRef]');
has 'review'              => (is => 'ro', isa => 'Maybe[Str]');
has 'status'              => (is => 'ro', isa => 'Str');

method form_fields {
    return $self->form_fields_for(qw/
        amount amount_to_capture application_fee_amount cancellation_reason
        capture_method client_secret confirm confirmation_method currency
        customer description error_on_requires_action expand mandate
        mandate_data metadata off_session on_behalf_of payment_method
        payment_method_options payment_method_types receipt_email return_url
        save_payment_method setup_future_usage shipping statement_descriptor
        statement_descriptor_suffix transfer_data transfer_group use_stripe_sdk
    /);
}

__PACKAGE__->meta->make_immutable;
1;
