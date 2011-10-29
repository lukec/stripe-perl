package Net::Stripe::Customer;
use Moose;
use methods;
extends 'Net::Stripe::Resource';

# Customer creation args
has 'email'       => (is => 'rw', isa => 'Str');
has 'description' => (is => 'rw', isa => 'Str');
has 'trial_end'   => (is => 'rw', isa => 'Int');
has 'card'        => (is => 'rw', isa => 'StripeCard');
has 'plan'        => (is => 'rw', isa => 'StripePlan');
has 'coupon'      => (is => 'rw', isa => 'StripeCoupon');

# API object args
has 'id'           => (is => 'ro', isa => 'Str');
has 'deleted'      => (is => 'ro', isa => 'Bool', default => 0);
has 'active_card'  => (is => 'ro', isa => 'StripeCard');
has 'subscription' => (is => 'ro', isa => 'Net::Stripe::Subscription');

method form_fields {
    return (
        $self->fields_for('card'),
        $self->fields_for('plan'),
        $self->fields_for('coupon'),
        map { ($_ => $self->$_) }
            grep { defined $self->$_ } qw/email description trial_end/
    );
}

__PACKAGE__->meta->make_immutable;
1;
