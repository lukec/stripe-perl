package Net::Stripe::Token;
use Moose;
use MooseX::Method::Signatures;
extends 'Net::Stripe::Resource';

# ABSTRACT: represent a Token object from Stripe

# Args for creating a Token
has 'card'        => (is => 'ro', isa => 'Maybe[Net::Stripe::Card]', required => 1);
has 'amount'      => (is => 'ro', isa => 'Maybe[Int]');
has 'currency'    => (is => 'ro', isa => 'Maybe[Str]');

# Args returned by the API
has 'id'          => (is => 'ro', isa => 'Maybe[Str]');
has 'created'     => (is => 'ro', isa => 'Maybe[Int]');
has 'used'        => (is => 'ro', isa => 'Maybe[Bool|Object]');
has 'livemode'    => (is => 'ro', isa => 'Maybe[Bool|Object]');

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
