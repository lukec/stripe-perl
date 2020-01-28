package Net::Stripe::Refund;

use Moose;
use Kavorka;
extends 'Net::Stripe::Resource';

# ABSTRACT: represent a Refund object from Stripe

has 'id'                  => (is => 'ro', isa => 'Maybe[Str]');
has 'amount'              => (is => 'ro', isa => 'Maybe[Int]');
has 'created'             => (is => 'ro', isa => 'Maybe[Int]');
has 'currency'            => (is => 'ro', isa => 'Maybe[Str]');
has 'balance_transaction' => (is => 'ro', isa => 'Maybe[Str]');
has 'charge'              => (is => 'ro', isa => 'Maybe[Str]');
has 'metadata'            => (is => 'ro', isa => 'Maybe[HashRef]');
has 'reason'              => (is => 'ro', isa => 'Maybe[Str]');
has 'receipt_number'      => (is => 'ro', isa => 'Maybe[Str]');
has 'status'              => (is => 'ro', isa => 'Maybe[Str]');
has 'description'         => (
    is      => 'ro',
    isa     => 'Maybe[Str]',
    lazy    => 1,
    default => sub {
        warn
            "Use of Net::Stripe::Refund->description is deprecated and will be removed in the next Net::Stripe release";
        return;
    }
);

# Create only
has 'refund_application_fee' => (is => 'ro', isa => 'Maybe[Bool|Object]');

method form_fields {
    return $self->form_fields_for(
        qw/amount refund_application_fee reason metadata/
    );
}

__PACKAGE__->meta->make_immutable;
1;
