package Net::Stripe::LineItem;

use Moose;

# ABSTRACT: represent an Line Item object from Stripe

has 'id'                => (is => 'ro', isa => 'Maybe[Str]');
has 'livemode'          => (is => 'ro', isa => 'Maybe[Bool]');
has 'amount'            => (is => 'ro', isa => 'Maybe[Int]');
has 'currency'          => (is => 'ro', isa => 'Maybe[Str]');
has 'period'            => (is => 'ro', isa => 'Maybe[HashRef]');
has 'proration'         => (is => 'ro', isa => 'Maybe[Bool]');
has 'type'              => (is => 'ro', isa => 'Maybe[Str]');
has 'description'       => (is => 'ro', isa => 'Maybe[Str]');
has 'metadata'          => (is => 'ro', isa => 'Maybe[HashRef]');
has 'plan'              => (is => 'ro', isa => 'Maybe[Net::Stripe::Plan]');
has 'quantity'          => (is => 'ro', isa => 'Maybe[Int]');

__PACKAGE__->meta->make_immutable;
1;
