package Net::Stripe::Card;

use Moose;
use Moose::Util::TypeConstraints qw(union);
use Kavorka;
use Net::Stripe::Token;

# ABSTRACT: represent a Card object from Stripe

# Input fields
has 'number'          => (is => 'ro', isa => 'Maybe[Str]');
has 'cvc'             => (is => 'ro', isa => 'Maybe[Int]');
has 'name'            => (is => 'ro', isa => 'Maybe[Str]');
has 'address_line1'   => (is => 'ro', isa => 'Maybe[Str]');
has 'address_line2'   => (is => 'ro', isa => 'Maybe[Str]');
has 'address_zip'     => (is => 'ro', isa => 'Maybe[Str]');
has 'address_state'   => (is => 'ro', isa => 'Maybe[Str]');
has 'address_country' => (is => 'ro', isa => 'Maybe[Str]');

# Both input and output
has 'exp_month'       => (is => 'ro', isa => 'Maybe[Int]', required => 1);
has 'exp_year'        => (is => 'ro', isa => 'Maybe[Int]', required => 1);

# Output fields
has 'id'                   => (is => 'ro', isa => 'Maybe[Str]');
has 'address_line_1_check' => (is => 'ro', isa => 'Maybe[Str]');
has 'address_zip_check'    => (is => 'ro', isa => 'Maybe[Str]');
has 'country'              => (is => 'ro', isa => 'Maybe[Str]');
has 'cvc_check'            => (is => 'ro', isa => 'Maybe[Str]');
has 'fingerprint'          => (is => 'ro', isa => 'Maybe[Str]');
has 'last4'                => (is => 'ro', isa => 'Maybe[Str]');
has 'brand'                => (is => 'ro', isa => 'Maybe[Str]');  # formerly 'type'

method form_fields {
    return (
        map { ("card[$_]" => $self->$_) }
            grep { defined $self->$_ }
                qw/number cvc name address_line1 address_line2 address_zip
                   address_state address_country exp_month exp_year/
    );
}

__PACKAGE__->meta->make_immutable;
1;
