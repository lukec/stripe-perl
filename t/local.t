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

my $API_KEY = 'sk_test_123';

foreach my $api_version ( qw/notanapiversionstring 20150216 2015-2-16/ ) {
    throws_ok {
        Net::Stripe->new(
            api_key     => $API_KEY,
            api_version => $api_version,
            debug       => 1,
        );
    } qr/of the form yyyy-mm-dd/, 'invalid api_version format';
}

eval {
    Net::Stripe->new(
        api_key     => $API_KEY,
        api_version => '2017-08-35',
        debug       => 1,
    );
};
if ( my $e = $@ ) {
    if ( Scalar::Util::blessed( $e ) && $e->isa( 'Net::Stripe::Error' ) ) {
        is $e->type, 'API version validation error', 'error type';
        like $e->message, qr/^Invalid date string/, 'error message';
    } else {
        fail sprintf( "error raised is a Net::Stripe::Error object: %s",
            Scalar::Util::blessed( $e ) || ref( $e ) || $e,
        );
    }
} else {
    fail 'report invalid api_version';
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

Request_parameter_encoding: {
    my $fffh = { Net::Stripe::Resource::form_fields_for_hashref(
        "hashref", { level1=> { level2=> "value" } }
    ) };
    is_deeply $fffh, { 'hashref[level1][level2]' => 'value' }, 'form_fields_for_hashref encoding';

    my $fffa = { Net::Stripe::Resource::form_fields_for_arrayref(
        "arrayref", [qw/ val1 val2 val3 /],
    ) };
    is_deeply $fffa, { 'arrayref[]' => [qw/ val1 val2 val3 /] }, 'form_fields_for_arrayref encoding';

    my $ctff = Net::Stripe::convert_to_form_fields(
        {
            "scalar" => "value",
            "arrayref" => [qw/ val1 val2 val3 /],
        }
    );
    is_deeply $ctff, {
        "scalar" => "value",
        "arrayref[]" => [qw/ val1 val2 val3 /],
    }, 'convert_to_form_fields ref encoding';

    is Net::Stripe::_encode_boolean( 1 ), 'true', 'encode boolean true';
    is Net::Stripe::_encode_boolean( 0 ), 'false', 'encode boolean false';
    ok !defined( Net::Stripe::_encode_boolean( undef ) ), 'encode boolean undef';
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
        StripeSourceId => {
            object => 'source',
            prefix => 'src_',
        },
        StripeProductId => {
            object => 'product',
            prefix => 'prod_',
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
    is_deeply $return, $expected, 'convert_to_form_fields object encoding';
}

List_pagination: {
    my $url = '/v1/customers';
    my @data_a;
    foreach my $i ( 1..5 ) {
        push @data_a, Net::Stripe::Customer->new(
            id => sprintf( 'cus_%02d', $i ),
        );
    }
    my $list_a = Net::Stripe::List->new(
        count => scalar( @data_a ),
        data => \@data_a,
        has_more => undef,
        url => $url,
    );

    my @data_b;
    foreach my $i ( 6..10 ) {
        push @data_b, Net::Stripe::Customer->new(
            id => sprintf( 'cus_%02d', $i ),
        );
    }
    my $list_b = Net::Stripe::List->new(
        count => scalar( @data_b ),
        data => \@data_b,
        has_more => undef,
        url => $url,
    );
    is_deeply { $list_b->_previous_page_args() }, { ending_before => 'cus_06' }, '_previous_page_args';
    is_deeply { $list_b->_next_page_args() }, { starting_after => 'cus_10' }, '_next_page_args';

    my $merged = Net::Stripe::List::_merge_lists(
        lists => [ $list_a, $list_b ],
    );
    is_deeply [ map { $_ ->id } $merged->elements ], [ map { $_->id } ( $list_a->elements, $list_b->elements ) ], 'merged list ids match';
    is $merged->url, $url, 'merged list url matches';
    ok defined( $merged->count ), 'merged list has count';
}

done_testing();
