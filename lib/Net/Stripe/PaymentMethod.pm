package Net::Stripe::PaymentMethod;

use Moose;
use Moose::Util::TypeConstraints qw(enum);
use Kavorka;
extends 'Net::Stripe::Resource';

# ABSTRACT: represent a PaymentMethod object from Stripe

# Args for posting to PaymentMethod endpoints
has 'billing_details' => (is => 'ro', isa => 'Maybe[HashRef]');
has 'card'            => (is => 'ro', isa => 'Maybe[Net::Stripe::Card|StripeTokenId]');
has 'fpx'             => (is => 'ro', isa => 'Maybe[HashRef]');
has 'ideal'           => (is => 'ro', isa => 'Maybe[HashRef]');
has 'metadata'        => (is => 'ro', isa => 'Maybe[HashRef[Str]|EmptyStr]');
has 'sepa_debit'      => (is => 'ro', isa => 'Maybe[HashRef]');
has 'type'            => (is => 'ro', isa => 'StripePaymentMethodType');

# Args returned by the API
has 'id'            => (is => 'ro', isa => 'StripePaymentMethodId');
has 'card_present'  => (is => 'ro', isa => 'Maybe[HashRef]');
has 'created'       => (is => 'ro', isa => 'Int');
has 'customer'      => (is => 'ro', isa => 'Maybe[StripeCustomerId]');
has 'livemode'      => (is => 'ro', isa => 'Bool');

method form_fields {
    return $self->form_fields_for(qw/
        billing_details card customer expand fpx ideal metadata sepa_debit type
    /);
}

__PACKAGE__->meta->make_immutable;
1;
