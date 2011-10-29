package Net::Stripe::Charge;
use Moose;
use methods;
extends 'Net::Stripe::Resource';

has 'id'          => (is => 'ro', isa => 'Str');
has 'created'     => (is => 'ro', isa => 'Int');
has 'fee'         => (is => 'ro', isa => 'Int');
has 'amount'      => (is => 'ro', isa => 'Int', required => 1);
has 'currency'    => (is => 'ro', isa => 'Str', required => 1);
has 'customer'    => (is => 'ro', isa => 'Str');
has 'card'        => (is => 'ro', isa => 'StripeCard');
has 'description' => (is => 'ro', isa => 'Str');
has 'livemode'    => (is => 'ro', isa => 'Bool');
has 'paid'        => (is => 'ro', isa => 'Bool');
has 'refunded'    => (is => 'ro', isa => 'Bool');

method form_fields {
    return (
        $self->fields_for('card'),
        map { $_ => $self->$_ }
            grep { defined $self->$_ }
                qw/amount currency customer description/
    );
}


__PACKAGE__->meta->make_immutable;
1;
