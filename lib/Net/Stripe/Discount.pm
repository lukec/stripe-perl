package Net::Stripe::Discount;

use Moose;
use Kavorka;
extends 'Net::Stripe::Resource';

# ABSTRACT: represent a Discount object from Stripe

has 'coupon' => (is => 'rw', isa => 'Maybe[Net::Stripe::Coupon]');
has 'start' => (is => 'rw', isa => 'Maybe[Int]');

__PACKAGE__->meta->make_immutable;
1;
