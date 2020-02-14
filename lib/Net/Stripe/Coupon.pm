package Net::Stripe::Coupon;

use Moose;
use Kavorka;
extends 'Net::Stripe::Resource';

# ABSTRACT: represent a Coupon object from Stripe

has 'id'                 => (is => 'rw', isa => 'Maybe[Str]');
has 'percent_off'        => (is => 'rw', isa => 'Maybe[Int]', required => 1);
has 'duration'           => (is => 'rw', isa => 'Maybe[Str]', required => 1);
has 'duration_in_months' => (is => 'rw', isa => 'Maybe[Int]');
has 'max_redemptions'    => (is => 'rw', isa => 'Maybe[Int]');
has 'redeem_by'          => (is => 'rw', isa => 'Maybe[Int]');
has 'metadata'           => (is => 'ro', isa => 'Maybe[HashRef]');

method form_fields {
    return $self->form_fields_for(
        qw/id percent_off duration duration_in_months max_redemptions redeem_by
            metadata/
    );
}

__PACKAGE__->meta->make_immutable;
1;
