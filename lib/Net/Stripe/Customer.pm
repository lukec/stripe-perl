package Net::Stripe::Customer;
use Moose;
use methods;
extends 'Net::Stripe::Resource';

# Customer creation args
has 'email'       => (is => 'rw', isa => 'Maybe[Str]');
has 'description' => (is => 'rw', isa => 'Maybe[Str]');
has 'trial_end'   => (is => 'rw', isa => 'Maybe[Int]');
has 'card'        => (is => 'rw', isa => 'Maybe[StripeCard]');
has 'plan'        => (is => 'ro', isa => 'Maybe[StripePlan]');
has 'coupon'      => (is => 'rw', isa => 'Maybe[StripeCoupon]');

# API object args
has 'id'           => (is => 'ro', isa => 'Maybe[Str]');
has 'deleted'      => (is => 'ro', isa => 'Maybe[Bool]', default => 0);
has 'active_card'  => (is => 'ro', isa => 'Maybe[StripeCard]');
has 'subscription' => (is => 'ro', isa => 'Maybe[Net::Stripe::Subscription]');

method form_fields {
    return (
        (($self->card && ref($self->card) eq 'Net::Stripe::Token') ?
            (card => $self->card->id) : $self->fields_for('card')),
        $self->fields_for('plan'),
        $self->fields_for('coupon'),
        map { ($_ => $self->$_) }
            grep { defined $self->$_ } qw/email description trial_end/
    );
}

=head1 NAME

Net::Stripe::Customer

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
