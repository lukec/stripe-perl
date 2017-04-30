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
has 'description'         => (is => 'ro', isa => 'Maybe[Str]');

# Create only
has 'refund_application_fee' => (is => 'ro', isa => 'Maybe[Bool|Object]');

method form_fields {
    return (
        $self->form_fields_for_metadata(),
        map { $_ => $self->$_ }
            grep { defined $self->$_ }
                qw/amount refund_application_fee reason/
    );
}

__PACKAGE__->meta->make_immutable;
1;
