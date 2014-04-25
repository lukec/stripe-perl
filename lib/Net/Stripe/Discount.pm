package Net::Stripe::Discount;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Method::Signatures;
extends 'Net::Stripe::Resource';

# ABSTRACT: represent a Discount object from Stripe

has 'coupon' => (is => 'rw', isa => 'Maybe[Net::Stripe::Coupon]');

__PACKAGE__->meta->make_immutable;
1;
