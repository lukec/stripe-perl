package Net::Stripe::Subscription;
use Moose;
use methods;
extends 'Net::Stripe::Resource';

has 'plan' => (is => 'ro', isa => 'Maybe[StripePlan]', required => 1);
has 'coupon'    => (is => 'ro', isa => 'Maybe[StripeCoupon]');
has 'prorate'   => (is => 'ro', isa => 'Maybe[Bool]');
has 'trial_end' => (is => 'ro', isa => 'Maybe[Int]');
has 'card'      => (is => 'ro', isa => 'Maybe[StripeCard]');

# Other fields returned by the API
has 'customer'             => (is => 'ro', isa => 'Maybe[Str]');
has 'status'               => (is => 'ro', isa => 'Maybe[Str]');
has 'start'                => (is => 'ro', isa => 'Maybe[Int]');
has 'canceled_at'          => (is => 'ro', isa => 'Maybe[Int]');
has 'ended_at'             => (is => 'ro', isa => 'Maybe[Int]');
has 'current_period_start' => (is => 'ro', isa => 'Maybe[Int]');
has 'current_period_end'   => (is => 'ro', isa => 'Maybe[Int]');
has 'trial_start'          => (is => 'ro', isa => 'Maybe[Str]');
has 'trial_end'            => (is => 'ro', isa => 'Maybe[Str]');


method form_fields {
    return (
        $self->fields_for('card'),
        $self->fields_for('plan'),
        map { ($_ => $self->$_) }
            grep { defined $self->$_ } qw/coupon prorate trial_end/
    );
}

=head1 NAME

Net::Stripe::Subscription

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
