package Net::Stripe::Product;

use Moose;
use Kavorka;
extends 'Net::Stripe::Resource';

# ABSTRACT: represent a Product object from Stripe

# Object creation
has 'active'                => (is => 'ro', isa => 'Maybe[Bool]');
has 'attributes'            => (is => 'ro', isa => 'Maybe[ArrayRef[Str]]');
has 'caption'               => (is => 'ro', isa => 'Maybe[Str]');
has 'deactivate_on'         => (is => 'ro', isa => 'Maybe[ArrayRef[Str]]');
has 'description'           => (is => 'ro', isa => 'Maybe[Str]');
has 'id'                    => (is => 'ro', isa => 'Maybe[StripeProductId|Str]');
has 'images'                => (is => 'ro', isa => 'Maybe[ArrayRef[Str]]');
has 'metadata'              => (is => 'ro', isa => 'Maybe[HashRef[Str]|EmptyStr]');
has 'name'                  => (is => 'ro', isa => 'Maybe[Str]');
has 'package_dimensions'    => (is => 'ro', isa => 'Maybe[HashRef[Num]]');
has 'shippable'             => (is => 'ro', isa => 'Maybe[Bool]');
has 'statement_descriptor'  => (is => 'ro', isa => 'Maybe[Str]');
has 'type'                  => (is => 'ro', isa => 'Maybe[StripeProductType]');
has 'unit_label'            => (is => 'ro', isa => 'Maybe[Str]');
has 'url'                   => (is => 'ro', isa => 'Maybe[Str]');

# API response
has 'created'   => (is => 'ro', isa => 'Maybe[Int]');
has 'livemode'  => (is => 'ro', isa => 'Maybe[Bool]');
has 'updated'   => (is => 'ro', isa => 'Maybe[Int]');

method form_fields {
    return $self->form_fields_for(
        qw/ active attributes caption deactivate_on description id images
            metadata name package_dimensions shippable statement_descriptor
            type unit_label url /
    );
}

__PACKAGE__->meta->make_immutable;
1;
