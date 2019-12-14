package Net::Stripe::Balance;
use Moose;
extends 'Net::Stripe::Resource';

# ABSTRACT: represent a Balance object from Stripe

has 'livemode'          => (is => 'ro', isa => 'Bool');
has 'available'         => (is => 'ro', isa => 'ArrayRef[HashRef]');
has 'connect_reserved'  => (is => 'ro', isa => 'ArrayRef[HashRef]');
has 'pending'           => (is => 'ro', isa => 'ArrayRef[HashRef]');

__PACKAGE__->meta->make_immutable;
1;
