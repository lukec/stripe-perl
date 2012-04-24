package Net::Stripe::Coupon;
use Moose;
use Moose::Util::TypeConstraints;
use methods;
extends 'Net::Stripe::Resource';

union 'StripeCoupon', ['Str', 'Net::Stripe::Coupon'];

has 'id'                 => (is => 'rw', isa => 'Maybe[Str]');
has 'percent_off'        => (is => 'rw', isa => 'Maybe[Int]', required => 1);
has 'duration'           => (is => 'rw', isa => 'Maybe[Str]', required => 1);
has 'duration_in_months' => (is => 'rw', isa => 'Maybe[Int]');
has 'max_redemptions'    => (is => 'rw', isa => 'Maybe[Int]');
has 'redeem_by'          => (is => 'rw', isa => 'Maybe[Int]');

method form_fields {
    return (
        map { ($_ => $self->$_) }
            grep { defined $self->$_ }
                qw/id percent_off duration duration_in_months 
                   max_redemptions redeem_by/
    );
}

=head1 NAME

Net::Stripe::Coupon

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
