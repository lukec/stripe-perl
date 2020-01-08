package Net::Stripe::TypeConstraints;

use strict;
use Moose::Util::TypeConstraints qw/subtype as where message/;

# ABSTRACT: Custom Moose TypeConstraints for Net::Stripe object attributes and parameters

subtype 'StripeTokenId',
    as 'Str',
    where {
        /^tok_.+/
    },
    message {
        sprintf( "Value '%s' must be a token id string of the form tok_.+", $_ );
    };

subtype 'StripeCardId',
    as 'Str',
    where {
        /^card_.+/
    },
    message {
        sprintf( "Value '%s' must be a card id string of the form card_.+", $_ );
    };

subtype 'StripeCustomerId',
    as 'Str',
    where {
        /^cus_.+/
    },
    message {
        sprintf( "Value '%s' must be a customer id string of the form cus_.+", $_ );
    };

1;
