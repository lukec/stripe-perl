package Net::Stripe::Customer;
use Moose;
use methods;
extends 'Net::Stripe::Resource';

# Customer creation args
has 'email'       => (is => 'rw', isa => 'Str');
has 'description' => (is => 'rw', isa => 'Str');
has 'trial_end'   => (is => 'rw', isa => 'Int');
has 'card'        => (is => 'rw', isa => 'Maybe[StripeCard]');
has 'plan'        => (is => 'rw', isa => 'Maybe[Net::Stripe::Plan]');
has 'coupon'      => (is => 'rw', isa => 'Maybe[Net::Stripe::Coupon]');

# API object args
has 'id'          => (is => 'rw', isa => 'Str');
has 'deleted'     => (is => 'rw', isa => 'Bool', default => 0);
has 'active_card' => (is => 'rw', isa => 'Maybe[Net::Stripe::Card]');

method form_fields {
    my $meta = $self->meta;
    return (
        $self->card_form_fields,
        ($self->plan   ? (plan   => $self->plan->id)   : ()),
        ($self->coupon ? (coupon => $self->coupon->id) : ()),
        map { ($_ => $self->$_) }
            grep { defined $self->$_ } qw/email description trial_end/
    );
}

__PACKAGE__->meta->make_immutable;
1;
