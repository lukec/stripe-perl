package Net::Stripe::Source;

use Moose;
use Kavorka;
extends 'Net::Stripe::Resource';

# ABSTRACT: represent a Source object from Stripe

# Object creation
has 'amount'                => (is => 'ro', isa => 'Maybe[Int]');
has 'currency'              => (is => 'ro', isa => 'Maybe[Str]');
has 'flow'                  => (is => 'ro', isa => 'Maybe[StripeSourceFlow]');
has 'mandate'               => (is => 'ro', isa => 'Maybe[HashRef]');
has 'metadata'              => (is => 'ro', isa => 'Maybe[HashRef[Str]|EmptyStr]');
has 'owner'                 => (is => 'ro', isa => 'Maybe[HashRef]');
has 'receiver'              => (is => 'ro', isa => 'Maybe[HashRef]');
has 'redirect'              => (is => 'ro', isa => 'Maybe[HashRef]');
has 'source_order'          => (is => 'ro', isa => 'Maybe[HashRef]');
has 'statement_descriptor'  => (is => 'ro', isa => 'Maybe[Str]');
has 'token'                 => (is => 'ro', isa => 'Maybe[StripeTokenId]');
has 'type'                  => (is => 'ro', isa => 'Maybe[StripeSourceType]');
has 'usage'                 => (is => 'ro', isa => 'Maybe[StripeSourceUsage]');

# API response
has 'id'                    => (is => 'ro', isa => 'Maybe[StripeSourceId]');
has 'client_secret'         => (is => 'ro', isa => 'Maybe[Str]');
has 'created'               => (is => 'ro', isa => 'Maybe[Int]');
has 'livemode'              => (is => 'ro', isa => 'Maybe[Bool]');
has 'status'                => (is => 'ro', isa => 'Maybe[Str]');
has 'card'                  => (is => 'ro', isa => 'Maybe[Net::Stripe::Card]');

method form_fields {
    return $self->form_fields_for(
        qw/amount currency flow mandate metadata owner receiver redirect source_order statement_descriptor token type usage/
    );
}

__PACKAGE__->meta->make_immutable;
1;
