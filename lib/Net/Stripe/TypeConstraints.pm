package Net::Stripe::TypeConstraints;

use strict;
use Moose::Util::TypeConstraints;

subtype 'Net::Stripe::Types::api_version',
    as 'Str',
    where { Net::Stripe::TypeConstraints::m_api_version( $_ ) },
    message { "api_version expects yyyy-mm-dd: '$_'" };

sub m_api_version {
    return /^\d{4}-\d{2}-\d{2}$/;
}

1;
