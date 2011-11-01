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

=head1 NAME

Net::Stripe::Charge

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
