package Net::Stripe::Token;
use Moose;
use methods;
extends 'Net::Stripe::Resource';

# Args for creating a Token
has 'card'        => (is => 'ro', isa => 'Net::Stripe::Card', required => 1);
has 'amount'      => (is => 'ro', isa => 'Int');
has 'currency'    => (is => 'ro', isa => 'Str');

# Args returned by the API
has 'id'          => (is => 'ro', isa => 'Str');
has 'created'     => (is => 'ro', isa => 'Int');
has 'used'        => (is => 'ro', isa => 'Bool');
has 'livemode'    => (is => 'ro', isa => 'Bool');

method form_fields {
    return (
        (defined $self->card ? $self->card->form_fields : () ),
        map { $_ => $self->$_ }
            grep { defined $self->$_ }
                qw/amount currency/
    );
}


__PACKAGE__->meta->make_immutable;
1;
