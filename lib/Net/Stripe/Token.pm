package Net::Stripe::Token;

use Moose;
use Kavorka;
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
has 'type'        => (is => 'ro', isa => 'Maybe[Str]');
has 'client_ip'   => (is => 'ro', isa => 'Maybe[Str]');

method form_fields {
    return $self->form_fields_for(
        qw/amount currency card/
    );
}

__PACKAGE__->meta->make_immutable;
1;
