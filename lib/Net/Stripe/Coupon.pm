package Net::Stripe::Coupon;
use Moose;
use Moose::Util::TypeConstraints;
use methods;
extends 'Net::Stripe::Resource';

union 'StripeCoupon', ['Str', 'Net::Stripe::Coupon'];

has 'id'                 => (is => 'rw', isa => 'Str');
has 'percent_off'        => (is => 'rw', isa => 'Int', required => 1);
has 'duration'           => (is => 'rw', isa => 'Str', required => 1);
has 'duration_in_months' => (is => 'rw', isa => 'Int');
has 'max_redemptions'    => (is => 'rw', isa => 'Int');
has 'redeem_by'          => (is => 'rw', isa => 'Int');

method form_fields {
    return (
        map { ($_ => $self->$_) }
            grep { defined $self->$_ }
                qw/id percent_off duration duration_in_months 
                   max_redemptions redeem_by/
    );
}

__PACKAGE__->meta->make_immutable;
1;
