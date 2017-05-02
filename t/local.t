#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Test::Exception;

BEGIN {
    use_ok 'Net::Stripe';
}

Backward_compatible_change: {

my $false =  bless( do{\(my $o = 0)}, 'JSON::PP::Boolean' );

  my $DATA = {
    'client_ip' => '138.197.111.110',
    'object' => 'token',
    'type' => 'card',
    'used' => $false,
    'livemode' => $false,
    'created' => 1485554753,
    'id' => 'tok_A0jJrn6t42i20c',
      'card' => {
      'dynamic_last4' => undef,
      'metadata' => {},
      'address_zip' => undef,
      'address_state' => undef,
      'country' => 'US',
      'name' => 'Anonymous',
      'type' => 'Visa',
      'address_city' => undef,
      'id' => 'card_A0jJBpS5WyeymP',
      'last4' => '4242',
      'tokenization_method' => undef,
      'brand' => 'Visa',
      'exp_year' => 2018,
      'funding' => 'credit',
      'address_zip_check' => undef,
      'exp_month' => 1,
      'address_line2' => undef,
      'object' => 'card',
      'fingerprint' => 'gtmIjG1HiIh8Xkim',
      'cvc_check' => undef,
      'address_line1' => undef,
      'customer' => undef,
      'address_line1_check' => undef,
      'address_country' => undef
      }
  };

  Unexpected_keys_ignored: {
    my $obj =  Net::Stripe::_hash_to_object({
            %$DATA,
            'dummy_object' => {
              object  => 'foo_bar',
              garbage => 'bin',
            },
            dummy_scalar => 'rubbish',
    });
    is (ref($obj), 'Net::Stripe::Token', 'unmodelled data has no effect');
    ok (! exists($obj->{dummy_object}), 'dummy_object ignored');
    ok (! exists($obj->{dummy_scalar}), 'dummy_scalar ignored');
  }
}

# These tests should not do any network activity

Not_specify_api_credentials_should_raise_exception: {
    throws_ok { Net::Stripe->new } qr/\(api_key\) is required/;
}

done_testing();
