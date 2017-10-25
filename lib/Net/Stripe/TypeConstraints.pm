package Net::Stripe::TypeConstraints;

use strict;
use Moose::Util::TypeConstraints qw(subtype as where message);
use DateTime qw();

subtype 'Net::Stripe::Types::api_version',
    as 'Str',
    where {
        my $min = '2012-10-26';
        my $max = DateTime->now->ymd('-');
        return if $_ !~ /^\d{4}-\d{2}-\d{2}$/;
        return if $_ lt $min;
        return if $_ gt $max;
        return 1;
    },
    message {
        my $min = '2012-10-26';
        my $max = DateTime->now->ymd('-');
        if ($_ !~ /^\d{4}-\d{2}-\d{2}$/) {
            return sprintf("value '%s' must be a Stripe API version string of the form yyyy-mm-dd", $_);
        } elsif ($_ lt $min) {
            return sprintf("value '%s' must be %s or after", $_, $min);
        } elsif ($_ gt $max) {
            return sprintf("value '%s' must be %s or before", $_, $max);
        } else {
            # how do we get here? just in case :-)
            return sprintf("invalid Stripe API version: '%s'", $_);
        }
    };

1;
