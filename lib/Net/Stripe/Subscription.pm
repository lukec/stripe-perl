package Net::Stripe::Subscription;
use Moose;
use methods;
extends 'Net::Stripe::Resource';

has 'plan' => (is => 'ro', isa => 'StripePlan', required => 1);
has 'coupon'    => (is => 'ro', isa => 'StripeCoupon');
has 'prorate'   => (is => 'ro', isa => 'Bool');
has 'trial_end' => (is => 'ro', isa => 'Int');
has 'card'      => (is => 'ro', isa => 'StripeCard');

# Other fields returned by the API
has 'current_period_end'   => (is => 'ro', isa => 'Int');
has 'status'               => (is => 'ro', isa => 'Str');
has 'current_period_start' => (is => 'ro', isa => 'Int');
has 'start'                => (is => 'ro', isa => 'Int');
has 'trial_start'          => (is => 'ro', isa => 'Str');
has 'trial_end'            => (is => 'ro', isa => 'Str');
has 'customer'             => (is => 'ro', isa => 'Str');


method form_fields {
    return (
        $self->fields_for('card'),
        $self->fields_for('plan'),
        map { ($_ => $self->$_) }
            grep { defined $self->$_ } qw/coupon prorate trial_end/
    );
}

__PACKAGE__->meta->make_immutable;
1;
