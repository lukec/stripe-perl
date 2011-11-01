package Net::Stripe::Card;
use Moose;
use Moose::Util::TypeConstraints;
use methods;

union 'StripeCard', ['Str', 'Net::Stripe::Card', 'Net::Stripe::Token'];

# Input fields
has 'number'          => (is => 'ro', isa => 'Str');
has 'cvc'             => (is => 'ro', isa => 'Int');
has 'name'            => (is => 'ro', isa => 'Str');
has 'address_line1'   => (is => 'ro', isa => 'Str');
has 'address_line2'   => (is => 'ro', isa => 'Str');
has 'address_zip'     => (is => 'ro', isa => 'Str');
has 'address_state'   => (is => 'ro', isa => 'Str');
has 'address_country' => (is => 'ro', isa => 'Str');

# Both input and output
has 'exp_month'       => (is => 'ro', isa => 'Int', required => 1);
has 'exp_year'        => (is => 'ro', isa => 'Int', required => 1);

# Output fields
has 'country'         => (is => 'ro', isa => 'Str');
has 'cvc_check'       => (is => 'ro', isa => 'Str');
has 'last4'           => (is => 'ro', isa => 'Str');
has 'type'            => (is => 'ro', isa => 'Str');

method form_fields {
    return (
        map { ("card[$_]" => $self->$_) }
            grep { defined $self->$_ }
                qw/number cvc name address_line1 address_line2 address_zip
                   address_state address_country exp_month exp_year/
    );
}

=head1 NAME

Net::Stripe::Card

=head1 SEE ALSO

L<https://stripe.com>, L<https://stripe.com/docs/api>

=head1 AUTHORS

Luke Closs

=head1 LICENSE

Net-Stripe is Copyright 2011 Prime Radiant, Inc.
Net-Stripe is distributed under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;
1;
