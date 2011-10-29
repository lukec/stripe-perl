package Net::Stripe::Coupon;
use Moose;
use Moose::Util::TypeConstraints;
use methods;
extends 'Net::Stripe::Resource';

union 'StripeCoupon', ['Str', 'Net::Stripe::Coupon'];

method form_fields {
    return (
        map { ($_ => $self->$_) }
            grep { defined $self->$_ } qw//
    );
}

__PACKAGE__->meta->make_immutable;
1;
