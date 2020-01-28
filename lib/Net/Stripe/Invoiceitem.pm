package Net::Stripe::Invoiceitem;

use Moose;
use Kavorka;
extends 'Net::Stripe::Resource';
with 'MooseX::Clone';

# ABSTRACT: represent an Invoice Item object from Stripe

has 'id'                => (is => 'ro', isa => 'Maybe[Str]');
has 'customer'          => (is => 'ro', isa => 'Maybe[Str]', required => 1);
has 'amount'            => (is => 'rw', isa => 'Maybe[Int]', required => 1);
has 'currency'          => (is => 'rw', isa => 'Maybe[Str]', required => 1, clearer => 'clear_currency');
has 'description'       => (is => 'rw', isa => 'Maybe[Str]');
has 'date'              => (is => 'ro', isa => 'Maybe[Int]');
has 'invoice'           => (is => 'ro', isa => 'Maybe[Str]');
has 'metadata'          => (is => 'rw', isa => 'Maybe[HashRef]');

method form_fields {
    return $self->form_fields_for(
        qw/amount currency description invoice metadata/,
        ($self->id ? () : qw/customer/)
    );
}

__PACKAGE__->meta->make_immutable;
1;
