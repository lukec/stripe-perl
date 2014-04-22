package Net::Stripe::Discount;
use Moose;
use Moose::Util::TypeConstraints;
use methods;
extends 'Net::Stripe::Resource';

has 'coupon' => (is => 'rw', isa => 'Maybe[Net::Stripe::Coupon]');


=head1 NAME

Net::Stripe::Discount

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
