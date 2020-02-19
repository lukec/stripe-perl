#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Test::Exception;
use DateTime;
use DateTime::Duration;

# These tests should not do any network activity

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

Not_specify_api_credentials_should_raise_exception: {
    throws_ok { Net::Stripe->new } qr/\(api_key\) is required/;
}

# add a temporary test for serializing multi-level hashrefs until we have
# actual methods with parameters that exercise this code
Placeholder: {
    my $return = { Net::Stripe::Resource::form_fields_for_hashref( "hashref", { level1=> { level2=> "value" } } ) };
    is_deeply $return, { 'hashref[level1][level2]' => 'value' };
}

TypeConstraints: {
    my %id_objects = (
        StripeTokenId => {
            object => 'token',
            prefix => 'tok_',
        },
        StripeCardId => {
            object => 'card',
            prefix => 'card_',
        },
        StripeCustomerId => {
            object => 'customer',
            prefix => 'cus_',
        },
    );
    foreach my $name ( sort( keys( %id_objects ) ) ) {
        my $constraint = Moose::Util::TypeConstraints::find_type_constraint( $name );
        my $object = $id_objects{$name}->{object};
        my $prefix = $id_objects{$name}->{prefix};
        my $valid = $prefix . '123';
        my $invalid = 'xxx_123';
        isa_ok $constraint, 'Moose::Meta::TypeConstraint';
        lives_ok { $constraint->assert_valid( $valid ) } "valid $object id";
        throws_ok { $constraint->assert_valid( $invalid ) } qr/Value '$invalid' must be a $object id string of the form $prefix\.\+/, "invalid $object id";
    }
    my $stripe_resource_type = Moose::Util::TypeConstraints::find_type_constraint( 'StripeResourceObject' );
    lives_ok { $stripe_resource_type->assert_valid( Net::Stripe::Customer->new() ) } "valid stripe resource object";
    throws_ok { $stripe_resource_type->assert_valid( DateTime->now ) } qr/Value '.+' must be an object that inherits from Net::Stripe::Resource with a 'form_fields' method/, "invalid stripe resource object";
}

# explicitly exercise a possibly-unused code path in convert_to_form_fields()
# in order to prevent regressions until we are able to verify that it is
# unused and properly deprecate it
For_later_deprecation: {
    my $future = DateTime->now + DateTime::Duration->new(months=> 1, years => 1);
    my $card_obj = Net::Stripe::Card->new(
        number => 4242424242424242,
        cvc => 123,
        exp_month => $future->month,
        exp_year => $future->year,
    );
    my $customer_obj = Net::Stripe::Customer->new(
        email => 'anonymous@example.com',
        account_balance => 1000,
    );
    # mimick previous code structure in convert_to_form_fields()
    my $expected;
    foreach my $obj ( $card_obj, $customer_obj ) {
        my %fields = $obj->form_fields();
        foreach my $fn (keys %fields) {
            $expected->{$fn} = $fields{$fn};
        }
    }
    my $return = Net::Stripe::convert_to_form_fields( {
        card => $card_obj,
        customer=> $customer_obj,
    } );
    is_deeply $return, $expected;
}

done_testing();
