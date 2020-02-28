package Net::Stripe::Subscription;

use Moose;
use Kavorka;
use Net::Stripe::Token;
use Net::Stripe::Card;
use Net::Stripe::Plan;
use Net::Stripe::Coupon;


extends 'Net::Stripe::Resource';

# ABSTRACT: represent a Subscription object from Stripe

has 'id' => (is => 'ro', isa => 'Maybe[Str]');
has 'plan' => (is => 'rw', isa => 'Maybe[Net::Stripe::Plan|Str]');
has 'coupon'    => (is => 'rw', isa => 'Maybe[Net::Stripe::Coupon|Str]');
has 'prorate'   => (is => 'rw', isa => 'Maybe[Bool|Object]');
has 'card'      => (is => 'rw', isa => 'Maybe[Net::Stripe::Token|Net::Stripe::Card|Str]');
has 'quantity'  => (is => 'rw', isa => 'Maybe[Int]', default => 1);

# Other fields returned by the API
has 'customer'             => (is => 'ro', isa => 'Maybe[Str]');
has 'status'               => (is => 'ro', isa => 'Maybe[Str]');
has 'start'                => (is => 'ro', isa => 'Maybe[Int]');
has 'canceled_at'          => (is => 'ro', isa => 'Maybe[Int]');
has 'ended_at'             => (is => 'ro', isa => 'Maybe[Int]');
has 'current_period_start' => (is => 'ro', isa => 'Maybe[Int]');
has 'current_period_end'   => (is => 'ro', isa => 'Maybe[Int]');
has 'trial_start'          => (is => 'ro', isa => 'Maybe[Str]');
has 'trial_end'            => (is => 'rw', isa => 'Maybe[Str|Int]');
has 'cancel_at_period_end' => (is => 'rw', isa => 'Maybe[Bool]');


method form_fields {
    return $self->form_fields_for(
        qw/coupon prorate trial_end quantity card plan cancel_at_period_end/
    );
}

__PACKAGE__->meta->make_immutable;
1;
