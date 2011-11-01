package Net::Stripe::Invoiceitem;
use Moose;
use methods;
extends 'Net::Stripe::Resource';

has 'id'                => (is => 'ro', isa => 'Str');
has 'customer'          => (is => 'ro', isa => 'Str', required => 1);
has 'amount'            => (is => 'rw', isa => 'Int', required => 1);
has 'currency'          => (is => 'rw', isa => 'Str', required => 1);
has 'description'       => (is => 'rw', isa => 'Str');
has 'date'              => (is => 'ro', isa => 'Int');

method form_fields {
    return (
        map { $_ => $self->$_ }
            grep { defined $self->$_ }
                qw/amount currency description/,
                ($self->id ? () : qw/customer/)
    );
}

__PACKAGE__->meta->make_immutable;
1;
