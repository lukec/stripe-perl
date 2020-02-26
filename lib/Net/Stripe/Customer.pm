package Net::Stripe::Customer;

use Moose;
use Kavorka;
use Net::Stripe::Plan;
use Net::Stripe::Token;
use Net::Stripe::Card;
use Net::Stripe::Discount;
use Net::Stripe::List;
extends 'Net::Stripe::Resource';

# ABSTRACT: represent a Customer object from Stripe

# Customer creation args
has 'email'       => (is => 'rw', isa => 'Maybe[Str]');
has 'description' => (is => 'rw', isa => 'Maybe[Str]');
has 'trial_end'   => (is => 'rw', isa => 'Maybe[Int|Str]');
has 'card'        => (is => 'rw', isa => 'Maybe[Net::Stripe::Token|Net::Stripe::Card|StripeTokenId]');
has 'source'      => (is => 'rw', isa => 'Maybe[Net::Stripe::Card|StripeTokenId|StripeSourceId]');
has 'quantity'    => (is => 'rw', isa => 'Maybe[Int]');
has 'plan'        => (is => 'rw', isa => 'Maybe[Net::Stripe::Plan|Str]');
has 'coupon'      => (is => 'rw', isa => 'Maybe[Net::Stripe::Coupon|Str]');
has 'discount'    => (is => 'rw', isa => 'Maybe[Net::Stripe::Discount]');
has 'metadata'    => (is => 'rw', isa => 'Maybe[HashRef]');
has 'account_balance' => (is => 'rw', isa => 'Maybe[Int]', trigger => \&_account_balance_trigger);
has 'balance'     => (is => 'rw', isa => 'Maybe[Int]', trigger => \&_balance_trigger);
has 'default_card' => (is => 'rw', isa => 'Maybe[Net::Stripe::Token|Net::Stripe::Card|Str]');
has 'default_source' => (is => 'rw', isa => 'Maybe[StripeCardId|StripeSourceId]');

# API object args

has 'id'           => (is => 'ro', isa => 'Maybe[Str]');
has 'cards'        => (is => 'ro', isa => 'Net::Stripe::List');
has 'deleted'      => (is => 'ro', isa => 'Maybe[Bool|Object]', default => 0);
has 'sources'      => (is => 'ro', isa => 'Net::Stripe::List');
has 'subscriptions' => (is => 'ro', isa => 'Net::Stripe::List');
has 'subscription' => (is => 'ro',
                       lazy => 1,
                       builder => '_build_subscription');

sub _build_subscription {
    my $self = shift;
    return $self->subscriptions->get(0);
}

method _account_balance_trigger(
    Maybe[Int] $new_value!,
    Maybe[Int] $old_value?,
) {
    return unless defined( $new_value );
    return if defined( $old_value ) && $old_value eq $new_value;
    return if defined( $self->balance ) && $self->balance == $new_value;
    $self->balance( $new_value );
}

method _balance_trigger(
    Maybe[Int] $new_value!,
    Maybe[Int] $old_value?,
) {
    return unless defined( $new_value );
    return if defined( $old_value ) && $old_value eq $new_value;
    return if defined( $self->account_balance ) && $self->account_balance == $new_value;
    $self->account_balance( $new_value );
}

method form_fields {
    $self->account_balance( undef ) if
        defined( $self->account_balance ) &&
        defined( $self->balance ) &&
        $self->account_balance == $self->balance;
    return $self->form_fields_for(
        qw/email description trial_end account_balance balance quantity card plan coupon
            metadata default_card source default_source/
    );
}

__PACKAGE__->meta->make_immutable;
1;
