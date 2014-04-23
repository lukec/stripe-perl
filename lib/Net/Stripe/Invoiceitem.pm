package Net::Stripe::Invoiceitem;
use Moose;
use methods;
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


method form_fields {
    return (
        map { $_ => $self->$_ }
            grep { defined $self->$_ }
                qw/amount currency description invoice/,
                ($self->id ? () : qw/customer/)
    );
}

__PACKAGE__->meta->make_immutable;
1;
