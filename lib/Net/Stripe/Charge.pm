package Net::Stripe::Charge;

use Moose;
use Kavorka;
extends 'Net::Stripe::Resource';

# ABSTRACT: represent an Charge object from Stripe

has 'id'                  => (is => 'ro', isa => 'Maybe[Str]');
has 'created'             => (is => 'ro', isa => 'Maybe[Int]');
has 'amount'              => (is => 'ro', isa => 'Maybe[Int]', required => 1);
has 'currency'            => (is => 'ro', isa => 'Maybe[Str]', required => 1);
has 'customer'            => (is => 'ro', isa => 'Maybe[StripeCustomerId]');
has 'card'                => (is => 'ro', isa => 'Maybe[Net::Stripe::Card|StripeTokenId|StripeCardId]');
has 'source'              => (is => 'ro', isa => 'Maybe[Net::Stripe::Card|Net::Stripe::Source|StripeTokenId|StripeCardId|StripeSourceId]');
has 'description'         => (is => 'ro', isa => 'Maybe[Str]');
has 'livemode'            => (is => 'ro', isa => 'Maybe[Bool|Object]');
has 'paid'                => (is => 'ro', isa => 'Maybe[Bool|Object]');
has 'refunded'            => (is => 'ro', isa => 'Maybe[Bool|Object]');
has 'amount_refunded'     => (is => 'ro', isa => 'Maybe[Int]');
has 'captured'            => (is => 'ro', isa => 'Maybe[Bool|Object]');
has 'balance_transaction' => (is => 'ro', isa => 'Maybe[Str]');
has 'failure_message'     => (is => 'ro', isa => 'Maybe[Str]');
has 'failure_code'        => (is => 'ro', isa => 'Maybe[Str]');
has 'application_fee'     => (is => 'ro', isa => 'Maybe[Int]');
has 'metadata'            => (is => 'rw', isa => 'Maybe[HashRef]');
has 'invoice'             => (is => 'ro', isa => 'Maybe[Str]');
has 'receipt_email'       => (is => 'ro', isa => 'Maybe[Str]');
has 'status'              => (is => 'ro', isa => 'Maybe[Str]');
has 'capture'             => (is => 'ro', isa => 'Bool', default=> 1);
has 'statement_descriptor' => (is => 'ro', isa => 'Maybe[Str]');
has 'refunds'             => (is => 'ro', isa => 'Net::Stripe::List');

method form_fields {
    return $self->form_fields_for(
        qw/amount currency customer description application_fee receipt_email
            capture statement_descriptor card source metadata/
    );
}

__PACKAGE__->meta->make_immutable;
1;
