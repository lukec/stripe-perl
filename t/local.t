#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Test::Exception;

BEGIN {
    use_ok 'Net::Stripe';
}

# These tests should not do any network activity

Not_specify_api_credentials_should_raise_exception: {
    throws_ok { Net::Stripe->new } qr/\(api_key\) is required/;
}

done_testing();
