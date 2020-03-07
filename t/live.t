#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warn;
use Net::Stripe;
use Net::Stripe::Constants;
use DateTime;
use DateTime::Duration;

my $API_KEY = $ENV{STRIPE_API_KEY};
unless ($API_KEY) {
    plan skip_all => "No STRIPE_API_KEY env var is defined.";
    exit;
}

unless ($API_KEY =~ m/^sk_test_/) {
    plan skip_all => "STRIPE_API_KEY env var MUST BE A TEST KEY to prevent modification of live data.";
    exit;
}

# configure a valid date within the supported range, but which is not a valid
# API version
my $INVALID_API_VERSION = '2012-10-27';
eval {
    Net::Stripe->new(
        api_key     => $API_KEY,
        api_version => $INVALID_API_VERSION,
        debug       => 1,
    );
};
if ( my $e = $@ ) {
    isa_ok $e, 'Net::Stripe::Error', 'error raised is an object';
    is $e->type, 'invalid_request_error', 'error type';
    is $e->message, sprintf( "Invalid Stripe API version: %s", $INVALID_API_VERSION ), 'error message';
} else {
    fail 'report invalid api_version';
}

# configure valid API versions, one less than min supported and one greater
# than max supported. either value may be undef, depending on whether the
# current SDK supports API versions from the start or through the current max.
my $UNSUPPORTED_API_VERSION_PRE = undef;
my $UNSUPPORTED_API_VERSION_POST = undef;
foreach my $api_version ( $UNSUPPORTED_API_VERSION_PRE, $UNSUPPORTED_API_VERSION_POST ) {
    next unless defined( $api_version );
    throws_ok {
        Net::Stripe->new(
            api_key     => $API_KEY,
            api_version => $api_version,
            debug       => 1,
        );
    } qr/is not supported by this version of Net::Stripe/, "unsupported api_version $api_version";

    lives_ok {
        Net::Stripe->new(
            api_key           => $API_KEY,
            api_version       => $api_version,
            force_api_version => 1,
            debug             => 1,
        );
    } "force unsupported api_version $api_version";
}

my $version_specific_stripe = Net::Stripe->new(
    api_key     => $API_KEY,
    api_version => Net::Stripe::Constants::MAX_API_VERSION,
    debug       => 1,
);
isa_ok $version_specific_stripe, 'Net::Stripe', sprintf( "API object created with explicit API version: %s", Net::Stripe::Constants::MAX_API_VERSION );
is $version_specific_stripe->api_version, Net::Stripe::Constants::MAX_API_VERSION, 'stripe object api_version matches';

# set future date to one year plus one month, since adding only one year
# currently matches default token expiration date, preventing us from
# discerning between the default expiration date and any expiration date
# that we are explicitly testing the setting of
my $future = DateTime->now + DateTime::Duration->new(months=> 1, years => 1);
my $future_ymdhms = $future->ymd('-') . '-' . $future->hms('-');

my $future_future = $future + DateTime::Duration->new(years => 1);

my $stripe = Net::Stripe->new(api_key => $API_KEY, debug => 1);
isa_ok $stripe, 'Net::Stripe', 'API object created today';

my $fake_card_exp = {
    exp_month => $future->month,
    exp_year  => $future->year,
};

my $fake_name = 'Anonymous';

my $fake_metadata = {
    'somemetadata' => 'testing, testing, 1-2-3',
};

my $fake_address = {
    line1       => '123 Main Street',
    line2       => '',
    city        => 'Anytown',
    state       => 'Anystate',
    postal_code => '55555',
    country     => 'US',
};

my $fake_email = 'anonymous@example.com';
my $fake_phone = '555-555-1212';

my $fake_card = {
    %$fake_card_exp,
    name      => $fake_name,
    metadata  => $fake_metadata,
};

for my $field ( sort( keys( %$fake_address ) ) ) {
  my $key = 'address_'.$field;
  $key = 'address_zip' if $key eq 'address_postal_code';
  $fake_card->{$key} = $fake_address->{$field};
}

my $updated_fake_card_exp = {
    exp_month => $future_future->month,
    exp_year  => $future_future->year,
};

my $updated_fake_name = 'Dr. Anonymous';

my $updated_fake_metadata = {
    'somenewmetadata' => 'can you hear me now?',
};

my $updated_fake_address = {
    line1       => '321 Easy Street',
    line2       => '',
    city        => 'Beverly Hills',
    state       => 'California',
    postal_code => '90210',
    country     => 'US',
};

my $updated_fake_email = 'dr.anonymous@example.com';
my $updated_fake_phone = '310-555-1212';

my $updated_fake_card = {
    %$updated_fake_card_exp,
    name      => $updated_fake_name,
    metadata  => $updated_fake_metadata,
};

for my $field ( sort( keys( %$updated_fake_address ) ) ) {
  my $key = 'address_'.$field;
  $key = 'address_zip' if $key eq 'address_postal_code';
  $updated_fake_card->{$key} = $updated_fake_address->{$field};
}

# passing a test token id to get_token() retrieves a token object with a card
# that has the same card number, based on the test token passed, but it has a
# unique card id each time, which is sufficient for the behaviors we are testing
my $token_id_visa = 'tok_visa';

Card_Tokens: {
    Basic_successful_use: {
        my $token = $stripe->get_token( token_id => $token_id_visa );
        isa_ok $token, 'Net::Stripe::Token', 'got a token back from post';

        is $token->type, 'card', 'token type is card';
        is $token->card->last4, '4242', 'token card';
        ok !$token->used, 'token is not used';
        ok !$token->livemode, 'token not created in livemode';

        my $same = $stripe->get_token(token_id => $token->id);
        isa_ok $same, 'Net::Stripe::Token', 'got a token back';
        is $same->id, $token->id, 'token id matches';
    }
}

Sources: {
    Create_for_payment_type_card: {
        eval {
            $stripe->create_source(
                type => 'card',
            );
        };
        if ($@) {
            my $e = $@;
            isa_ok $e, 'Net::Stripe::Error', 'error raised is an object';
            is $e->type, 'create_source error', 'error type';
            is $e->message, "Parameter 'token' is required for source type 'card'", 'error message';
            is $e->param, 'token', 'error param';
        } else {
            fail 'missing card';
        }

        my $source = $stripe->create_source(
            type => 'card',
            token => $token_id_visa,
        );
        isa_ok $source, 'Net::Stripe::Source';
        is $source->type, 'card', 'source type is card';

        ok defined( $source->card ), 'source has card';
        is $source->card->{last4}, '4242', 'card last4 matches';
    }

    # special source types are required to test the passing of:
    # mandate, redirect, source_order.
    # so we cannot test them at this time.
    Create_with_generic_fields: {
        my %source_args = (
            amount => 1234,
            currency => 'usd',
            owner => {
                address => $fake_address,
                email => $fake_email,
                name => $fake_name,
                phone => $fake_phone,
            },
            metadata => $fake_metadata,
            statement_descriptor => 'Statement Descriptor',
            usage => 'single_use',
        );
        my $source = $stripe->create_source(
            type => 'card',
            token => $token_id_visa,
            %source_args,
        );
        isa_ok $source, 'Net::Stripe::Source';
        for my $field (qw/amount client_secret created currency flow id livemode metadata owner statement_descriptor status type usage/) {
            ok defined( $source->$field ), "source has $field";
        }
    }

    Create_with_receiver_flow_fields: {
        my %source_args = (
            type => 'ach_credit_transfer',
            amount => 1234,
            currency => 'usd',
            flow => 'receiver',
            receiver => {
                refund_attributes_method => 'manual',
            },
            statement_descriptor => 'Statement Descr',
        );
        my $source = $stripe->create_source(
            %source_args,
        );
        isa_ok $source, 'Net::Stripe::Source';

        # we cannot use is_deeply on the entire hash because the returned
        # 'receiver' hash has some keys that do not exist in our hash
        for my $f ( sort( grep { $_ ne 'receiver' } keys( %source_args ) ) ) {
            is $source->$f, $source_args{$f}, "source $f matches";
        }
        for my $f ( sort( keys( %{$source_args{receiver}} ) ) ) {
            is $source->receiver->{$f}, $source_args{receiver}->{$f}, "source receiver $f matches";
        }
    }

    Retrieve: {
        my $source = $stripe->create_source(
            type => 'card',
            token => $token_id_visa,
        );
        isa_ok $source, 'Net::Stripe::Source';

        my $retrieved = $stripe->get_source( source_id => $source->id );
        isa_ok $retrieved, 'Net::Stripe::Source';
        is $retrieved->id, $source->id, 'retrieved source id matches';
    }

    Attach_and_detach: {
        my $source = $stripe->create_source(
            type => 'card',
            token => $token_id_visa,
        );
        isa_ok $source, 'Net::Stripe::Source';

        my $customer = $stripe->post_customer();
        my $attached = $stripe->attach_source(
            customer_id => $customer->id,
            source_id => $source->id
        );
        isa_ok $attached, 'Net::Stripe::Source';
        is $attached->id, $source->id, 'attached source id matches';

        my $sources = $stripe->list_sources(
            customer_id => $customer->id,
            object => 'source',
        );
        isa_ok $sources, 'Net::Stripe::List';
        my @sources = $sources->elements;
        is scalar( @sources ), 1, 'customer has one card';
        is $sources[0]->id, $source->id, "list element source id matches";

        my $detached = $stripe->detach_source(
            customer_id => $customer->id,
            source_id => $source->id,
        );
        isa_ok $detached, 'Net::Stripe::Source';
        is $detached->id, $source->id, "detached source id matches";
        is $detached->status, 'consumed', 'detached source status is "consumed"';

        $sources = $stripe->list_sources(
            customer_id => $customer->id,
            object => 'source',
        );
        isa_ok $sources, 'Net::Stripe::List';
        @sources = $sources->elements;
        is scalar( @sources ), 0, 'customer has zero cards';
    }

    Update: {
        my %source_args = (
            owner => {
                address => $fake_address,
                email => $fake_email,
                name => $fake_name,
                phone => $fake_phone,
            },
            metadata => $fake_metadata,
        );
        my $source = $stripe->create_source(
            type => 'card',
            token => $token_id_visa,
            %source_args,
        );
        isa_ok $source, 'Net::Stripe::Source';

        # we cannot use is_deeply on the entire hash because the returned
        # 'owner' hash has some keys that do not exist in our hash
        for my $f ( sort( grep { $_ ne 'owner' } keys( %source_args ) ) ) {
            is_deeply $source->$f, $source_args{$f}, "source $f matches";
        }
        for my $f ( sort( keys( %{$source_args{owner}} ) ) ) {
            is_deeply $source->owner->{$f}, $source_args{owner}->{$f}, "source owner $f matches";
        }

        my %updated_source_args = (
            owner => {
                address => $updated_fake_address,
                email => $updated_fake_email,
                name => $updated_fake_name,
                phone => $updated_fake_phone,
            },
            metadata => $updated_fake_metadata,
        );
        my $updated = $stripe->update_source(
            source_id => $source->id,
            %updated_source_args,
        );

        for my $f ( sort( grep { $_ ne 'owner' } keys( %updated_source_args ) ) ) {
            if ( ref( $updated_source_args{$f} ) eq 'HASH' ) {
                my $merged = { %{$source_args{$f} || {}}, %{$updated_source_args{$f} || {}} };
                is_deeply $updated->$f, $merged, "updated source $f matches";
            } else {
                is $updated->$f, $updated_source_args{$f}, "updated source $f matches";
            }
        }

        for my $f ( sort( grep { $_ !~ /^verified_/ } keys( %{$updated_source_args{owner}} ) ) ) {
            is_deeply $updated->owner->{$f}, $updated_source_args{owner}->{$f}, "updated source owner $f matches";
        }

        $updated = $stripe->update_source(
            source_id => $source->id,
            metadata => '',
        );
        is_deeply $updated->metadata, {}, "cleared source metadata";

        eval {
            $stripe->update_source(
                source_id => $source->id,
            );
        };
        if ($@) {
            my $e = $@;
            isa_ok $e, 'Net::Stripe::Error', 'error raised is an object';
            is $e->type, 'update_source error', 'error type';
            like $e->message, qr/^at least one of: .+ is required to update a source$/, 'error message';
        } else {
            fail 'missing param';
        }
    }

}

Products: {
    Create_retrieve_delete: {
        my %product_args = (
            name => 'Product Name',
            type => 'good',
        );
        my $product = $stripe->create_product(
            %product_args,
        );
        isa_ok $product, 'Net::Stripe::Product';
        # confirm the persistent attributes. other attributes will be
        # confirmed by actual value when set.
        for my $field (
            qw/ id created livemode updated /
        ) {
            ok defined( $product->$field ), "product has $field";
        }
        for my $f ( sort( keys( %product_args ) ) ) {
            is $product->$f, $product_args{$f}, "product $f matches";
        }

        my $retrieved = $stripe->get_product(
            product_id => $product->id,
        );
        isa_ok $retrieved, 'Net::Stripe::Product';
        is $retrieved->id, $product->id, 'retrieved product id matches';

        my $hash = $stripe->delete_product( product_id => $product->id );
        ok $hash->{deleted}, 'product successfully deleted';
        is $hash->{id}, $product->id, 'deleted product id is correct';
    }

    Custom_id: {
        my $custom_id = 'custom_product_id_' . $future_ymdhms;
        my $product = $stripe->create_product(
            id => $custom_id,
            name => 'Product Name',
            type => 'good',
        );
        is $product->id, $custom_id, "custom id matches";
    }

    Clear_metadata: {
        my $product = $stripe->create_product(
            name => 'Product Name',
            metadata => $fake_metadata,
        );
        my $updated = $stripe->update_product(
            product_id => $product->id,
            metadata => '',
        );
        is_deeply $updated->metadata, {}, "cleared product metadata";
    }

    Create_and_update_goods: {
        my %product_args = (
            active => 0,
            attributes => [qw/ size color /],
            caption => 'Product Caption',
            description => 'Product Description',
            images => [ map { sprintf( 'https://example.com/images/product-pic-%s.png', $_ ) } ( 1..8 ) ],
            metadata => $fake_metadata,
            name => 'Product Name',
            package_dimensions => {
                height => 0.12,
                length => 3.45,
                weight => 6.78,
                width => 9.01,
            },
            shippable => 0,
            type => 'good',
            url => 'https://example.com/product.php',
        );
        my $product = $stripe->create_product(
            %product_args,
        );
        isa_ok $product, 'Net::Stripe::Product';
        for my $f ( sort( keys( %product_args ) ) ) {
            is_deeply $product->$f, $product_args{$f}, "product $f matches";
        }

        my %updated_product_args = (
            active => 1,
            attributes => [qw/ finish material /],
            caption => 'Updated Product Caption',
            description => 'Updated Product Description',
            images => [ map { sprintf( 'https://example.com/images/product-pic-%s-high-res.png', $_ ) } ( 1..8 ) ],
            metadata => $updated_fake_metadata,
            name => 'Updated Product Name',
            package_dimensions => {
                height => 9.87,
                length => 6.54,
                weight => 3.21,
                width => 0.98,
            },
            shippable => 1,
            url => 'https://example.com/updated-product.php',
        );
        my $updated = $stripe->update_product(
            product_id => $product->id,
            %updated_product_args,
        );
        isa_ok $updated, 'Net::Stripe::Product';
        for my $f ( sort( grep { $_ ne 'attributes' } keys( %updated_product_args ) ) ) {
            if ( ref( $updated_product_args{$f} ) eq 'HASH' ) {
                my $merged = { %{$product_args{$f} || {}}, %{$updated_product_args{$f} || {}} };
                is_deeply $updated->$f, $merged, "updated product $f matches";
            } else {
                is_deeply $updated->$f, $updated_product_args{$f}, "updated product $f matches";
            }
        }
        # get details on failed comparison by using sorted results with is_deeply instead of using eq_set
        is_deeply [ sort @{$updated->attributes} ], [ sort @{$updated_product_args{attributes}} ], "updated product attributes matches";
    }

    Create_and_update_services: {
        my %product_args = (
            active => 0,
            description => 'Hourly Service Description',
            images => [ map { sprintf( 'https://example.com/images/service-pic-%s.png', $_ ) } ( 1..8 ) ],
            metadata => $fake_metadata,
            name => 'Hourly Service Name',
            statement_descriptor => 'Statement Descr',
            type => 'service',
            unit_label => 'Hour(s)',
        );
        my $product = $stripe->create_product(
            %product_args,
        );
        isa_ok $product, 'Net::Stripe::Product';
        for my $f ( sort( keys( %product_args ) ) ) {
            is_deeply $product->$f, $product_args{$f}, "service $f matches";
        }

        my %updated_product_args = (
            active => 1,
            description => 'Daily Service Description',
            images => [ map { sprintf( 'https://example.com/images/service-pic-%s-high-res.png', $_ ) } ( 1..8 ) ],
            metadata => $updated_fake_metadata,
            name => 'Daily Service Name',
            statement_descriptor => 'Updtd Statement Descr',
            unit_label => 'Day(s)',
        );
        my $updated = $stripe->update_product(
            product_id => $product->id,
            %updated_product_args,
        );
        isa_ok $updated, 'Net::Stripe::Product';
        for my $f ( sort( keys( %updated_product_args ) ) ) {
            if ( ref( $updated_product_args{$f} ) eq 'HASH' ) {
                my $merged = { %{$product_args{$f} || {}}, %{$updated_product_args{$f} || {}} };
                is_deeply $updated->$f, $merged, "updated service $f matches";
            } else {
                is_deeply $updated->$f, $updated_product_args{$f}, "updated service $f matches";
            }
        }
    }

    List: {
        my (
            @product_ids,
            %active_ids,
            %shippable_ids,
            %type_ids,
            @product_urls,
        );
        note "creating products";
        foreach my $i ( 1..5 ) {
            foreach my $active ( 0, 1 ) {
                my $product = $stripe->create_product(
                    name => sprintf(
                        '%s Product #%02d',
                        $active ? 'Active' : 'InActive',
                        $i,
                    ),
                    type => 'good',
                    active => $active,
                );
                push @product_ids, $product->id;
                push @{$active_ids{$active}}, $product->id;
            }
            foreach my $shippable ( 0, 1 ) {
                my $product = $stripe->create_product(
                    name => sprintf(
                        '%s Product #%02d',
                        ( $shippable ? '' : 'Non-' ) . 'Shippable',
                        $i,
                    ),
                    type => 'good',
                    shippable => $shippable,
                    url => sprintf(
                        'https://example.com/%s-product-%s-%02d.php',
                        ( $shippable ? '' : 'non-' ) . 'shippable',
                        $future_ymdhms,
                        $i,
                    ),
                );
                push @product_ids, $product->id;
                push @{$shippable_ids{$shippable}}, $product->id;
                push @product_urls, $product->url;
            }
            foreach my $type ( qw/ good service / ) {
                my $product = $stripe->create_product(
                    name => sprintf(
                        '%s #%02d',
                        $type eq 'service' ? 'Service' : 'Product',
                        $i,
                    ),
                    type => $type,
                );
                push @product_ids, $product->id;
                push @{$type_ids{$type}}, $product->id;
            }
        }

        my @subset = @product_ids[0..4];
        my $products = $stripe->list_products(
            ids => \@subset,
        );
        isa_ok $products, 'Net::Stripe::List';
        is_deeply [ sort map { $_ ->id } $products->elements ], [ sort @subset ], 'retrieved fixed id list';

        foreach my $active ( sort( keys( %active_ids ) ) ) {
            my $products = $stripe->list_products(
                active => $active,
                limit => 0,
            );
            isa_ok $products, 'Net::Stripe::List';

            # since we cannot be sure that our newly-created objects are
            # the only ones that exist, we must simply confirm that they are
            # somewhere in the list
            my %seeking = map { $_ => 1 } @{$active_ids{$active} || []};
            foreach my $product ( $products->elements ) {
                delete( $seeking{$product->id} ) if exists( $seeking{$product->id} );
            }
            is_deeply \%seeking, {}, "retrieved product objects for active '$active'";
        }

        foreach my $shippable ( sort( keys( %shippable_ids ) ) ) {
            my $products = $stripe->list_products(
                shippable => $shippable,
                limit => 0,
            );
            isa_ok $products, 'Net::Stripe::List';

            # since we cannot be sure that our newly-created objects are
            # the only ones that exist, we must simply confirm that they are
            # somewhere in the list
            my %seeking = map { $_ => 1 } @{$shippable_ids{$shippable} || []};
            foreach my $product ( $products->elements ) {
                delete( $seeking{$product->id} ) if exists( $seeking{$product->id} );
            }
            is_deeply \%seeking, {}, "retrieved product objects for shippable '$shippable'";
        }

        foreach my $type ( sort( keys( %type_ids ) ) ) {
            my $products = $stripe->list_products(
                type => $type,
                limit => 0,
            );
            isa_ok $products, 'Net::Stripe::List';

            # since we cannot be sure that our newly-created objects are
            # the only ones that exist, we must simply confirm that they are
            # somewhere in the list
            my %seeking = map { $_ => 1 } @{$type_ids{$type} || []};
            foreach my $product ( $products->elements ) {
                delete( $seeking{$product->id} ) if exists( $seeking{$product->id} );
            }
            is_deeply \%seeking, {}, "retrieved product objects for type '$type'";
        }

        my $url = $product_urls[ rand( @product_urls ) ];
        $products = $stripe->list_products(
            url => $url,
        );
        isa_ok $products, 'Net::Stripe::List';
        my @products = $products->elements;
        is scalar( @products ), 1, 'retrieved one product object by url';
        is $products[0]->url, $url, 'retrieved product object url matches';

        note "deleting product objects";
        $stripe->delete_product( product_id => $_ ) for @product_ids;
    }
}

Plans: {
    Basic_successful_use: {
        my $product = $stripe->create_product(
            name => "Test Service - $future",
            type => 'service',
        );
        # Notice that the plan ID requires uri escaping
        my $id = $future_ymdhms;
        my %plan_args = (
            id => $id,
            amount => 0,
            currency => 'usd',
            interval => 'month',
            product => $product->id,
            trial_period_days => 10,
            metadata => {
                'somemetadata' => 'hello world',
            },
        );
        my $plan = $stripe->post_plan( %plan_args );
        isa_ok $plan, 'Net::Stripe::Plan';
        for my $f ( sort( keys( %plan_args ) ) ) {
            is_deeply $plan->$f, $plan_args{$f}, "plan $f matches";
        }

        my $newplan = $stripe->get_plan(plan_id => $id);
        isa_ok $newplan, 'Net::Stripe::Plan';
        is $newplan->id, $id, 'Plan id was encoded correctly';
        for my $f ( sort( keys( %plan_args ) ) ) {
            is_deeply $newplan->$f, $plan->$f, "$f matches for both plans";
        }

        my $plans = $stripe->get_plans(limit => 1);
        is scalar(@{$plans->data}), 1, 'got just one plan';
        is $plans->get(0)->id, $id, 'plan id matches';
        is $plans->last->id, $id, 'plan id matches';

        my $hash = $stripe->delete_plan($plan);
        ok $hash->{deleted}, 'delete response indicates delete was successful';
        is $hash->{id}, $id, 'deleted id is correct';
        eval {
            # swallow the expected warning rather than have it print out during tests.
            local $SIG{__WARN__} = sub {};
            $stripe->get_plan(plan_id => $id);
        };
        if ($@) {
            my $e = $@;
            isa_ok $e, 'Net::Stripe::Error', 'error raised is an object';
            is $e->type, 'invalid_request_error', 'error type';
            is $e->message, "No such plan: $id", 'error message';
        } else {
            fail "no longer can fetch deleted plans";

        }
    }
}

Coupons: {
    Basic_successful_use: {
        my $id = "coupon-$future_ymdhms";
        my %coupon_args = (
            id => $id,
            percent_off => 50,
            duration => 'repeating',
            duration_in_months => 3,
            max_redemptions => 5,
            redeem_by => time() + 100,
            metadata => {
                'somemetadata' => 'hello world',
            },
        );
        my $coupon = $stripe->post_coupon( %coupon_args );
        isa_ok $coupon, 'Net::Stripe::Coupon';
        for my $f ( sort( keys( %coupon_args ) ) ) {
            is_deeply $coupon->$f, $coupon_args{$f}, "coupon $f matches";
        }

        my $newcoupon = $stripe->get_coupon(coupon_id => $id);
        isa_ok $newcoupon, 'Net::Stripe::Coupon';
        is $newcoupon->id, $id, 'coupon id was encoded correctly';
        for my $f ( sort( keys( %coupon_args ) ) ) {
            is_deeply $newcoupon->$f, $coupon->$f, "$f matches for both coupon";
        }

        my $coupons = $stripe->get_coupons(limit => 1);
        is scalar(@{$coupons->data}), 1, 'got just one coupon';
        is $coupons->get(0)->id, $id, 'coupon id matches';

        my $hash = $stripe->delete_coupon($coupon);
        ok $hash->{deleted}, 'delete response indicates delete was successful';
        is $hash->{id}, $id, 'deleted id is correct';
        eval {
            # swallow the expected warning rather than have it print out during tests.
            local $SIG{__WARN__} = sub {};
            $stripe->get_coupon(coupon_id => $id);
        };
        if ($@) {
            my $e = $@;
            isa_ok $e, 'Net::Stripe::Error', 'error raised is an object';
            is $e->type, 'invalid_request_error', 'error type';
            is $e->message, "No such coupon: $id", 'error message';
        } else {
            fail "no longer can fetch deleted coupons";

        }
    }
}

Charges: {
    Basic_successful_use: {
        my $charge;
        lives_ok {
            $charge = $stripe->post_charge(
                amount => 3300,
                currency => 'usd',
                source => $token_id_visa,
                description => 'Wikileaks donation',
                statement_descriptor => 'Statement Descr',
            );
        } 'Created a charge object';
        isa_ok $charge, 'Net::Stripe::Charge';
        for my $field (qw/id amount card source created currency description
                          livemode paid refunded status statement_descriptor/) {
            ok defined($charge->$field), "charge has $field";
        }
        ok !$charge->refunded, 'charge is not refunded';
        ok $charge->paid, 'charge was paid';
        like $charge->status, qr/^(?:paid|succeeded)$/, 'charge was successful';
        ok $charge->captured, 'charge was captured';
        is $charge->statement_descriptor, 'Statement Descr', 'charge statement_descriptor matches';

        # Check out the returned card object
        my $source = $charge->source;
        isa_ok $source, 'Net::Stripe::Card';

        # Fetch a charge
        my $charge2;
        lives_ok { $charge2 = $stripe->get_charge(charge_id => $charge->id) }
            'Fetching a charge works';
        is $charge2->id, $charge->id, 'Charge ids match';

        # Refund a charge
        my $refund;
        # partial refund
        lives_ok { $refund = $stripe->refund_charge(charge => $charge->id, amount => 1000) }
            'refunding a charge works';
        isa_ok $refund, 'Net::Stripe::Refund';
        is $refund->charge, $charge->id, 'returned charge object matches id';
        is $refund->status, 'succeeded', 'status is "succeeded"';
        is $refund->amount, 1000, 'partial refund $10';
        warning_like { $refund->description() } qr{deprecated}, 'warning for deprecated attribute';        
        lives_ok { $charge = $stripe->get_charge(charge_id => $charge->id) }
            'Fetching updated charge works';
        ok !$charge->refunded, 'charge not yet fully refunded';
        # fully refund
        lives_ok { $refund = $stripe->refund_charge(charge => $charge->id) }
            'refunding remainder of charge';
        is $refund->charge, $charge->id, 'returned charge object matches id';
        lives_ok { $charge = $stripe->get_charge(charge_id => $charge->id) }
            'Fetching updated charge works';
        ok $charge->refunded, 'charge is fully refunded';

        # Fetch list of charges
        my $charges = $stripe->get_charges( limit => 1 );
        is scalar(@{$charges->data}), 1, 'one charge returned';
        is $charges->get(0)->id, $charge->id, 'charge ids match';

        # simulate address_line1_check failure
        lives_ok {
            $charge = $stripe->post_charge(
                amount => 3300,
                currency => 'usd',
                source => 'tok_avsLine1Fail',
                description => 'Wikileaks donation',
            );
        } 'Created a charge object';
        isa_ok $charge, 'Net::Stripe::Charge';

        # Check out the returned card object
        $source = $charge->source;
        isa_ok $source, 'Net::Stripe::Card';
        is $source->address_line1_check, 'fail', 'card address_line1_check';
    }

    Charge_with_metadata: {
        my $charge;
        lives_ok {
            $charge = $stripe->post_charge(
                amount => 2500,
                currency => 'usd',
                source => $token_id_visa,
                description => 'Testing Metadata',
                metadata => {'hasmetadata' => 'hello world'},
            );
        } 'Created a charge object with metadata';
        isa_ok $charge, 'Net::Stripe::Charge';
        ok defined($charge->metadata), "charge has metadata";        
        is $charge->metadata->{'hasmetadata'}, 'hello world', 'charge metadata';
        my $charge2 = $stripe->get_charge(charge_id => $charge->id);
        is $charge2->metadata->{'hasmetadata'}, 'hello world', 'charge metadata in retrieved object';
    }

    Post_charge_using_token_id: {
        my $token = $stripe->get_token( token_id => $token_id_visa );
        my $charge = $stripe->post_charge(
            amount => 100,
            currency => 'usd',
            source => $token->id,
        );
        isa_ok $charge, 'Net::Stripe::Charge';
        ok $charge->paid, 'charge was paid';
        like $charge->status, qr/^(?:paid|succeeded)$/, 'charge was successful';
        isa_ok $charge->source, 'Net::Stripe::Card';
        is $charge->source->id, $token->card->id, 'charge card id matches';

        $token = $stripe->get_token( token_id => $token_id_visa );
        $charge = $stripe->post_charge(
            amount => 100,
            currency => 'usd',
            card => $token->id,
        );
        isa_ok $charge, 'Net::Stripe::Charge';
        ok $charge->paid, 'charge was paid';
        like $charge->status, qr/^(?:paid|succeeded)$/, 'charge was successful';
        is $charge->card->id, $token->card->id, 'charge card id matches';
    }

    Post_charge_using_card_id: {
        my $token = $stripe->get_token( token_id => $token_id_visa );
        eval {
             $stripe->post_charge(
                amount => 100,
                currency => 'usd',
                source => $token->card->id,
            );
        };
        if ($@) {
            my $e = $@;
            isa_ok $e, 'Net::Stripe::Error', 'error raised is an object';
            is $e->type, 'post_charge error', 'error type';
            like $e->message, qr/^Invalid value 'card_.+' passed for parameter 'source'\. Charges without an existing customer can only accept a token id or source id\.$/, 'error message';
        } else {
            fail 'post source charge with card id';
        }

        $token = $stripe->get_token( token_id => $token_id_visa );
        eval {
             $stripe->post_charge(
                amount => 100,
                currency => 'usd',
                card => $token->card->id,
            );
        };
        if ($@) {
            my $e = $@;
            isa_ok $e, 'Net::Stripe::Error', 'error raised is an object';
            is $e->type, 'post_charge error', 'error type';
            like $e->message, qr/^Invalid value 'card_.+' passed for parameter 'card'\. Charges without an existing customer can only accept a token id\.$/, 'error message';
        } else {
            fail 'post card charge with card id';
        }
    }

    Post_charge_using_source_id: {
        my $source = $stripe->create_source(
            type => 'card',
            token => $token_id_visa,
        );
        my $charge = $stripe->post_charge(
            amount => 100,
            currency => 'usd',
            source => $source->id,
        );
        isa_ok $charge, 'Net::Stripe::Charge';
        ok $charge->paid, 'charge was paid';
        like $charge->status, qr/^(?:paid|succeeded)$/, 'charge was successful';
        is $charge->source->type, 'card', 'charge source type is card';
        is $charge->source->id, $source->id, 'charge source id matches';
    }

    Post_charge_for_customer_id_with_attached_card: {
        my $customer = $stripe->post_customer(
            source => $token_id_visa,
        );
        my $charge = $stripe->post_charge(
            amount => 100,
            currency => 'usd',
            customer => $customer->id,
        );
        isa_ok $charge, 'Net::Stripe::Charge';
        ok $charge->paid, 'charge was paid';
        like $charge->status, qr/^(?:paid|succeeded)$/, 'charge was successful';
        is $charge->source->id, $customer->default_source, 'charged default source';

        $customer = $stripe->post_customer(
            card => $token_id_visa,
        );
        $charge = $stripe->post_charge(
            amount => 100,
            currency => 'usd',
            customer => $customer->id,
        );
        isa_ok $charge, 'Net::Stripe::Charge';
        ok $charge->paid, 'charge was paid';
        like $charge->status, qr/^(?:paid|succeeded)$/, 'charge was successful';
        is $charge->card->id, $customer->default_card, 'charged default card';
    }

    Post_charge_for_customer_id_with_attached_source: {
        my $token = $stripe->get_token( token_id => $token_id_visa );
        my $source = $stripe->create_source(
            type => 'card',
            token => $token->id,
        );
        my $customer = $stripe->post_customer();
        my $customer_id = $customer->id;
        $stripe->attach_source(
            customer_id => $customer_id,
            source_id => $source->id,
        );
        $customer = $stripe->get_customer(
            customer_id => $customer_id,
        );

        my $charge = $stripe->post_charge(
            amount => 100,
            currency => 'usd',
            customer => $customer_id,
        );
        isa_ok $charge, 'Net::Stripe::Charge';
        ok $charge->paid, 'charge was paid';
        like $charge->status, qr/^(?:paid|succeeded)$/, 'charge was successful';
        is $charge->source->id, $customer->default_source, 'charged default source';
        is $charge->source->id, $source->id, 'charge source id matches';
    }

    Post_charge_for_customer_id_without_attached_card: {
        my $customer = $stripe->post_customer();
        eval {
            # swallow the expected warning rather than have it print out during tests.
            local $SIG{__WARN__} = sub {};
            $stripe->post_charge(
                amount => 100,
                currency => 'usd',
                customer => $customer->id,
            );
        };
        if ($@) {
            my $e = $@;
            isa_ok $e, 'Net::Stripe::Error', 'error raised is an object';
            is $e->type, 'card_error', 'error type';
            is $e->message, 'Cannot charge a customer that has no active card', 'error message';
        } else {
            fail 'post charge for customer with token id';
        }
    }

    Post_charge_for_customer_id_using_token_id: {
        my $customer = $stripe->post_customer();
        eval {
            $stripe->post_charge(
                amount => 100,
                currency => 'usd',
                customer => $customer->id,
                source => $token_id_visa,
            );
        };
        if ($@) {
            my $e = $@;
            isa_ok $e, 'Net::Stripe::Error', 'error raised is an object';
            is $e->type, 'post_charge error', 'error type';
            like $e->message, qr/^Invalid value 'tok_.+' passed for parameter 'source'\. Charges for an existing customer can only accept a card id\.$/, 'error message';
        } else {
            fail 'post source charge for customer with token id';
        }

        $customer = $stripe->post_customer();
        eval {
            $stripe->post_charge(
                amount => 100,
                currency => 'usd',
                customer => $customer->id,
                card => $token_id_visa,
            );
        };
        if ($@) {
            my $e = $@;
            isa_ok $e, 'Net::Stripe::Error', 'error raised is an object';
            is $e->type, 'post_charge error', 'error type';
            like $e->message, qr/^Invalid value 'tok_.+' passed for parameter 'card'\. Charges for an existing customer can only accept a card id\.$/, 'error message';
        } else {
            fail 'post card charge for customer with token id';
        }
    }

    Post_charge_for_customer_id_using_card_id: {
        # customer may have multiple cards. allow ability to select a specific
        # card for a given charge.

        my $customer = $stripe->post_customer();
        my $card = $stripe->post_card(
            customer => $customer,
            source => $token_id_visa,
        );
        for ( 1..3 ) {
            my $other_card = $stripe->post_card(
                customer => $customer,
                source => $token_id_visa,
            );
            isnt $card->id, $other_card->id, 'different card id';
        }
        my $charge = $stripe->post_charge(
            amount => 100,
            currency => 'usd',
            customer => $customer->id,
            source => $card->id,
        );
        isa_ok $charge, 'Net::Stripe::Charge';
        ok $charge->paid, 'charge was paid';
        like $charge->status, qr/^(?:paid|succeeded)$/, 'charge was successful';
        is $charge->source->id, $card->id, 'charge card id matches';

        $customer = $stripe->post_customer();
        $card = $stripe->post_card(
            customer => $customer,
            card => $token_id_visa,
        );
        for ( 1..3 ) {
            my $other_card = $stripe->post_card(
                customer => $customer,
                card => $token_id_visa,
            );
            isnt $card->id, $other_card->id, 'different card id';
        }
        $charge = $stripe->post_charge(
            amount => 100,
            currency => 'usd',
            customer => $customer->id,
            card => $card->id,
        );
        isa_ok $charge, 'Net::Stripe::Charge';
        ok $charge->paid, 'charge was paid';
        like $charge->status, qr/^(?:paid|succeeded)$/, 'charge was successful';
        is $charge->card->id, $card->id, 'charge card id matches';
    }

    Rainy_day: {
        # swallow the expected warning rather than have it print out during tests.
        local $SIG{__WARN__} = sub {};
        # Test a charge with no source or customer
        eval {
            $stripe->post_charge(
                amount => 3300,
                currency => 'usd',
                description => 'Wikileaks donation',
            );

        };
        if ($@) {
            my $e = $@;
            isa_ok $e, 'Net::Stripe::Error', 'error raised is an object';
            is $e->type, 'invalid_request_error', 'error type';
            is $e->message, 'Must provide source or customer.', 'error message';
        } else {
            fail 'must provide source or customer';
        }

        # Test an invalid currency
        eval {
            $stripe->post_charge(
                amount => 3300,
                currency => 'zzz',
                source => $token_id_visa,
            );
        };
        if ($@) {
            my $e = $@;
            isa_ok $e, 'Net::Stripe::Error', 'error raised is an object';
            is $e->type, 'invalid_request_error', 'error type';
            like $e->message, '/^Invalid currency: zzz/', 'error message';
            is $e->param, 'currency', 'error param';
        } else {
            fail 'report invalid currency';
        }
    }

    Charge_with_receipt_email: {
        my $charge;
        lives_ok {
            $charge = $stripe->post_charge(
                amount => 2500,
                currency => 'usd',
                source => $token_id_visa,
                description => 'Testing Receipt Email',
                receipt_email => 'stripe@example.com',
            );
        } 'Created a charge object with receipt_email';
        isa_ok $charge, 'Net::Stripe::Charge';
        ok defined($charge->receipt_email), "charge has receipt_email";
        is $charge->receipt_email, 'stripe@example.com', 'charge receipt_email';
        my $charge2 = $stripe->get_charge(charge_id => $charge->id);
        is $charge2->receipt_email, 'stripe@example.com', 'charge receipt_email in retrieved object';
    }

    Auth_then_capture: {
        my $charge;
        lives_ok {
            $charge = Net::Stripe::Charge->new(
                amount => 3300,
                currency => 'usd',
                source => $token_id_visa,
                description => 'Wikileaks donation',
                capture => 0,
            );
        } 'Created a charge object';
        isa_ok $charge, 'Net::Stripe::Charge';
        is $charge->capture, 0, 'capture is zero';

        my $amount = 1234;
        lives_ok {
            $charge = $stripe->post_charge(
                amount => $amount,
                currency => 'usd',
                source => $token_id_visa,
                description => 'Wikileaks donation',
                capture => 0,
            );
        } 'Created a charge object';

        isa_ok $charge, 'Net::Stripe::Charge';
        for my $field (qw/id amount created currency description
                          livemode paid refunded/) {
            ok defined($charge->$field), "charge has $field";
        }
        ok !$charge->refunded, 'charge is not refunded';
        ok $charge->paid, 'charge was paid';
        ok !$charge->captured, 'charge was not captured';
        is $charge->balance_transaction, undef, 'balance_transaction is undef';
        is $charge->amount, $amount, "amount is $amount";

        my $auth_charge_id = $charge->id;
        my $captured_charge = $stripe->capture_charge(
            charge => $auth_charge_id,
        );
        ok !$captured_charge->refunded, 'charge is not refunded';
        ok $captured_charge->paid, 'charge was paid';
        ok $captured_charge->captured, 'charge was captured';
        ok defined($captured_charge->balance_transaction), 'balance_transaction is defined';
        is $captured_charge->amount, $amount, "amount is $amount";
        is $captured_charge->id, $charge->id, 'Charge ids match';
    }

    Auth_then_partial_capture: {
        my $amount = 1234;
        my $charge = $stripe->post_charge(
            amount => $amount,
            currency => 'usd',
            card => $token_id_visa,
            capture => 0,
        );
        isa_ok $charge, 'Net::Stripe::Charge';
        ok !$charge->refunded, 'charge is not refunded';
        ok $charge->paid, 'charge was paid';
        ok !$charge->captured, 'charge was not captured';
        ok !defined( $charge->balance_transaction ), 'balance_transaction is undef';
        is $charge->amount, $amount, "amount matches";
        my $refunds = $charge->refunds;
        isa_ok $refunds, "Net::Stripe::List";
        my @refunds = $refunds->elements;
        is scalar( @refunds ), 0, 'charge has no refunds';

        my $auth_charge_id = $charge->id;
        my $partial = 567;
        my $captured_charge = $stripe->capture_charge(
            charge => $auth_charge_id,
            amount => $partial,
        );
        ok !$captured_charge->refunded, 'charge is not refunded';
        ok $captured_charge->paid, 'charge was paid';
        ok $captured_charge->captured, 'charge was captured';
        ok defined( $captured_charge->balance_transaction ), 'balance_transaction is defined';
        is $captured_charge->amount, $amount, "amount matches";
        is $captured_charge->id, $charge->id, 'Charge ids match';
        is $captured_charge->amount_refunded, $amount - $partial, "amount_refunded matches";
        $refunds = $captured_charge->refunds;
        isa_ok $refunds, "Net::Stripe::List";
        @refunds = $refunds->elements;
        is scalar( @refunds ), 1, 'charge has one refund';
        is $refunds[0]->amount, $amount - $partial, "refund amount matches";
        is $refunds[0]->status, 'succeeded', 'refund was successful';
    }
}

Customers: {
    Basic_successful_use: {
        GET_POST_DELETE: {
            my $customer = $stripe->post_customer();
            isa_ok $customer, 'Net::Stripe::Customer', 'got back a customer';
            my $id = $customer->id;
            ok $id, 'customer has an id';
            for my $f (qw/card source coupon email description plan trial_end/) {
                is $customer->$f, undef, "customer has no $f";
            }
            ok !$customer->deleted, 'customer is not deleted';

            # Update an existing customer
            $customer->description("Test user for Net::Stripe");
            my $samesy = $stripe->post_customer(customer => $customer);
            is $samesy->description, $customer->description,
                'post_customer returns an updated customer object';
            my $same = $stripe->get_customer(customer_id => $id);
            is $same->description, $customer->description,
                'get customer retrieves an updated customer';

            # Fetch the list of customers
            my $all = $stripe->get_customers(limit => 1);
            is scalar(@{$all->data}), 1, 'only one customer returned';
            is $all->get(0)->id, $customer->id, 'correct customer returned';

            # Delete a customer
            $stripe->delete_customer(customer => $customer);
            $customer = $stripe->get_customer(customer_id => $id);
            ok $customer->{deleted}, 'customer is now deleted';

            # Test pagination through customer lists

            # Make sure that we have at least 15 customers
            my @new_customer_ids;
            for (1..15) {
                my $customer = $stripe->post_customer();
                push @new_customer_ids, $customer->id;
            }

            my $first_five = $stripe->get_customers(limit=> 5);
            is scalar(@{$first_five->data}), 5, 'five customers returned';
            my $second_five = $stripe->get_customers(
                limit=> 5,
                starting_after=> $first_five->last->id,
            );
            is scalar(@{$second_five->data}), 5, 'five customers returned';
            my $third_five = $stripe->get_customers(
                limit=> 5,
                starting_after=> $second_five->last->id,
            );
            is scalar(@{$third_five->data}), 5, 'five customers returned';

            my $previous_five = $stripe->get_customers(
                limit=> 5,
                ending_before=> $third_five->get(0)->id,
            );
            is scalar(@{$previous_five->data}), 5, 'five customers returned';

            my @second_five_ids = sort map { $_->id } @{$second_five->data};
            my @previous_five_ids = sort map { $_->id } @{$previous_five->data};
            is_deeply(\@second_five_ids, \@previous_five_ids, 'ids match');

            # Delete the customers that we created
            $stripe->delete_customer(customer=> $_) for @new_customer_ids;
        }

        Customer_with_metadata: {
            my $customer = $stripe->post_customer(
                email => 'stripe@example.com',
                description => 'Test for Net::Stripe',
                metadata => {'somemetadata' => 'hello world'},
            );
            is $customer->metadata->{'somemetadata'}, 'hello world', 'customer metadata';
        }

        Customer_with_balance: {
            Create: {
                my $balance = 1000;
                my $customer = $stripe->post_customer(
                    account_balance => $balance,
                );
                isa_ok $customer, 'Net::Stripe::Customer';
                is $customer->account_balance, $balance, 'account_balance matches';
                is $customer->balance, $balance, 'balance matches';

                $customer = $stripe->post_customer(
                    balance => $balance,
                );
                isa_ok $customer, 'Net::Stripe::Customer';
                is $customer->balance, $balance, 'balance matches';
                is $customer->account_balance, $balance, 'account_balance matches';
            }

            Update_for_customer_id: {
                my $balance = 1000;
                my $customer = $stripe->post_customer(
                    account_balance => $balance,
                );
                isa_ok $customer, 'Net::Stripe::Customer';
                is $customer->account_balance, $balance, 'account_balance matches';
                is $customer->balance, $balance, 'balance matches';

                $balance = 999;
                $customer = $stripe->post_customer(
                    customer => $customer->id,
                    account_balance => $balance,
                );
                isa_ok $customer, 'Net::Stripe::Customer';
                is $customer->account_balance, $balance, 'account_balance matches';
                is $customer->balance, $balance, 'balance matches';

                $balance = 1000;
                $customer = $stripe->post_customer(
                    balance => $balance,
                );
                isa_ok $customer, 'Net::Stripe::Customer';
                is $customer->account_balance, $balance, 'account_balance matches';
                is $customer->balance, $balance, 'balance matches';

                $balance = 999;
                $customer = $stripe->post_customer(
                    customer => $customer->id,
                    balance => $balance,
                );
                isa_ok $customer, 'Net::Stripe::Customer';
                is $customer->account_balance, $balance, 'account_balance matches';
                is $customer->balance, $balance, 'balance matches';
            }

            Update_for_customer_object: {
                my $balance = 1000;
                my $customer = $stripe->post_customer(
                    account_balance => $balance,
                );
                isa_ok $customer, 'Net::Stripe::Customer';
                is $customer->account_balance, $balance, 'account_balance matches';
                is $customer->balance, $balance, 'balance matches';

                $balance = 999;
                $customer->account_balance( $balance );
                $customer = $stripe->post_customer(
                    customer => $customer,
                );
                isa_ok $customer, 'Net::Stripe::Customer';
                is $customer->account_balance, $balance, 'account_balance matches';
                is $customer->balance, $balance, 'balance matches';

                $balance = 1000;
                $customer = $stripe->post_customer(
                    balance => $balance,
                );
                isa_ok $customer, 'Net::Stripe::Customer';
                is $customer->account_balance, $balance, 'account_balance matches';
                is $customer->balance, $balance, 'balance matches';

                $balance = 999;
                $customer->balance( $balance );
                $customer = $stripe->post_customer(
                    customer => $customer,
                );
                isa_ok $customer, 'Net::Stripe::Customer';
                is $customer->account_balance, $balance, 'account_balance matches';
                is $customer->balance, $balance, 'balance matches';
            }

        }

        Retrieve_via_email: {
            my $email_address = 'stripe' . time() . '@example.com';
            my $customer = $stripe->post_customer(
                email => $email_address,
            );
            my $customers = $stripe->get_customers(
              email => $email_address,
            );
            is scalar(@{$customers->data}), 1, 'only one customer returned';
            is $customers->get(0)->id, $customer->id, 'correct customer returned';

            $stripe->delete_customer(customer => $customer->id);
            $customer = $stripe->get_customer(customer_id => $customer->id);
            ok $customer->{deleted}, 'customer is now deleted';
        }

        Create_with_a_token_id: {
            my $token = $stripe->get_token( token_id => $token_id_visa );
            my $customer = $stripe->post_customer(
                source => $token->id,
            );
            isa_ok $customer, 'Net::Stripe::Customer', 'got back a customer';
            ok $customer->id, 'customer has an id';
            my $card = $stripe->get_card(
                customer => $customer,
                card_id => $customer->default_source,
            );
            is $card->id, $token->card->id, 'token card id matches';
        }

        Create_with_a_token_id_card: {
            my $token = $stripe->get_token( token_id => $token_id_visa );
            my $customer = $stripe->post_customer(
                card => $token->id,
            );
            isa_ok $customer, 'Net::Stripe::Customer', 'got back a customer';
            ok $customer->id, 'customer has an id';
            my $card = $stripe->get_card(
                customer => $customer,
                card_id => $customer->default_card,
            );
            is $card->id, $token->card->id, 'token card id matches';
        }

        Create_with_a_token_object: {
            my $token = $stripe->get_token( token_id => $token_id_visa );
            my $customer = $stripe->post_customer(
                card => $token,
            );
            isa_ok $customer, 'Net::Stripe::Customer', 'got back a customer';
            ok $customer->id, 'customer has an id';
            my $card = $stripe->get_card(
                customer => $customer,
                card_id => $customer->default_card,
            );
            is $card->id, $token->card->id, 'token card id matches';
        }

        Update_source_for_customer_id_via_token_id: {
            my $customer = $stripe->post_customer(
                source => $token_id_visa,
            );
            isa_ok $customer, 'Net::Stripe::Customer', 'got back a customer';
            ok $customer->id, 'customer has an id';

            my $cards = $stripe->get_cards(customer => $customer);
            isa_ok $cards, "Net::Stripe::List";
            is scalar @{$cards->data}, 1, 'customer has one card';
            my $card = @{$cards->data}[0];
            isa_ok $card, "Net::Stripe::Card";

            $stripe->post_customer(
                customer => $customer->id,
                source => $token_id_visa,
            );
            $cards = $stripe->get_cards(customer => $customer);
            isa_ok $cards, "Net::Stripe::List";
            is scalar @{$cards->data}, 1, 'customer still has one card';
            my $new_card = @{$cards->data}[0];
            isnt $new_card->id, $card->id, 'new card has different card id';
        }

        Update_card_for_customer_id_via_token_id: {
            my $customer = $stripe->post_customer(
                card => $token_id_visa,
            );
            isa_ok $customer, 'Net::Stripe::Customer', 'got back a customer';
            ok $customer->id, 'customer has an id';

            my $cards = $stripe->get_cards(customer => $customer);
            isa_ok $cards, "Net::Stripe::List";
            is scalar @{$cards->data}, 1, 'customer has one card';
            my $card = @{$cards->data}[0];
            isa_ok $card, "Net::Stripe::Card";

            $stripe->post_customer(
                customer => $customer->id,
                card => $token_id_visa,
            );
            $cards = $stripe->get_cards(customer => $customer);
            isa_ok $cards, "Net::Stripe::List";
            is scalar @{$cards->data}, 1, 'customer still has one card';
            my $new_card = @{$cards->data}[0];
            isnt $new_card->id, $card->id, 'new card has different card id';
        }

        Update_source_for_customer_object_via_token_id: {
            my $customer = $stripe->post_customer(
                source => $token_id_visa,
            );
            isa_ok $customer, 'Net::Stripe::Customer', 'got back a customer';
            ok $customer->id, 'customer has an id';

            my $cards = $stripe->get_cards(customer => $customer);
            isa_ok $cards, "Net::Stripe::List";
            is scalar @{$cards->data}, 1, 'customer has one card';
            my $card = @{$cards->data}[0];
            isa_ok $card, "Net::Stripe::Card";

            $customer->source($token_id_visa);
            # we must unset the default_card attribute in the existing object.
            # otherwise there is a conflict since the old default_card id is
            # serialized in the POST stream, and it appears that we are
            # requesting to set default_card to the id of a card that no
            # longer exists, but rather is being replaced by the new card.
            $customer->default_card(undef);
            $customer->default_source(undef);
            $stripe->post_customer(customer => $customer);
            $cards = $stripe->get_cards(customer => $customer);
            isa_ok $cards, "Net::Stripe::List";
            is scalar @{$cards->data}, 1, 'customer still has one card';
            my $new_card = @{$cards->data}[0];
            isnt $new_card->id, $card->id, 'new card has different card id';
        }

        Update_card_for_customer_object_via_token_id: {
            my $customer = $stripe->post_customer(
                card => $token_id_visa,
            );
            isa_ok $customer, 'Net::Stripe::Customer', 'got back a customer';
            ok $customer->id, 'customer has an id';

            my $cards = $stripe->get_cards(customer => $customer);
            isa_ok $cards, "Net::Stripe::List";
            is scalar @{$cards->data}, 1, 'customer has one card';
            my $card = @{$cards->data}[0];
            isa_ok $card, "Net::Stripe::Card";

            $customer->card($token_id_visa);
            # we must unset the default_card attribute in the existing object.
            # otherwise there is a conflict since the old default_card id is
            # serialized in the POST stream, and it appears that we are
            # requesting to set default_card to the id of a card that no
            # longer exists, but rather is being replaced by the new card.
            $customer->default_card(undef);
            $customer->default_source(undef);
            $stripe->post_customer(customer => $customer);
            $cards = $stripe->get_cards(customer => $customer);
            isa_ok $cards, "Net::Stripe::List";
            is scalar @{$cards->data}, 1, 'customer still has one card';
            my $new_card = @{$cards->data}[0];
            isnt $new_card->id, $card->id, 'new card has different card id';
        }

        Update_card_for_customer_id_via_token_object: {
            my $customer = $stripe->post_customer(
                card => $token_id_visa,
            );
            isa_ok $customer, 'Net::Stripe::Customer', 'got back a customer';
            ok $customer->id, 'customer has an id';

            my $cards = $stripe->get_cards(customer => $customer);
            isa_ok $cards, "Net::Stripe::List";
            is scalar @{$cards->data}, 1, 'customer has one card';
            my $card = @{$cards->data}[0];
            isa_ok $card, "Net::Stripe::Card";

            my $new_token = $stripe->get_token( token_id => $token_id_visa );
            $stripe->post_customer(
                customer => $customer->id,
                card => $new_token,
            );
            $cards = $stripe->get_cards(customer => $customer);
            isa_ok $cards, "Net::Stripe::List";
            is scalar @{$cards->data}, 1, 'customer still has one card';
            my $new_card = @{$cards->data}[0];
            isnt $new_card->id, $card->id, 'new card has different card id';
        }

        Update_card_for_customer_object_via_token_object: {
            my $customer = $stripe->post_customer(
                card => $token_id_visa,
            );
            isa_ok $customer, 'Net::Stripe::Customer', 'got back a customer';
            ok $customer->id, 'customer has an id';

            my $cards = $stripe->get_cards(customer => $customer);
            isa_ok $cards, "Net::Stripe::List";
            is scalar @{$cards->data}, 1, 'customer has one card';
            my $card = @{$cards->data}[0];
            isa_ok $card, "Net::Stripe::Card";

            my $new_token = $stripe->get_token( token_id => $token_id_visa );
            $customer->card($new_token);
            # we must unset the default_card attribute in the existing object.
            # otherwise there is a conflict since the old default_card id is
            # serialized in the POST stream, and it appears that we are
            # requesting to set default_card to the id of a card that no
            # longer exists, but rather is being replaced by the new card.
            $customer->default_card(undef);
            $customer->default_source(undef);
            $stripe->post_customer(customer => $customer);
            $cards = $stripe->get_cards(customer => $customer);
            isa_ok $cards, "Net::Stripe::List";
            is scalar @{$cards->data}, 1, 'customer still has one card';
            my $new_card = @{$cards->data}[0];
            isnt $new_card->id, $card->id, 'new card has different card id';
        }

        Add_source_for_customer_object_via_token_id: {
            my $customer = $stripe->post_customer(
                source => $token_id_visa,
            );
            isa_ok $customer, 'Net::Stripe::Customer', 'got back a customer';
            ok $customer->id, 'customer has an id';

            my $cards = $stripe->get_cards(customer => $customer);
            isa_ok $cards, "Net::Stripe::List";
            is scalar @{$cards->data}, 1, 'customer has one card';
            my $card = @{$cards->data}[0];
            isa_ok $card, "Net::Stripe::Card";

            my $new_card = $stripe->post_card(
                customer => $customer,
                source => $token_id_visa,
            );
            isnt $new_card->id, $card->id, 'new card has different card id';

            $cards = $stripe->get_cards(customer => $customer);
            isa_ok $cards, "Net::Stripe::List";
            is scalar @{$cards->data}, 2, 'customer has two cards';
        }

        Add_card_for_customer_object_via_token_id: {
            my $customer = $stripe->post_customer(
                card => $token_id_visa,
            );
            isa_ok $customer, 'Net::Stripe::Customer', 'got back a customer';
            ok $customer->id, 'customer has an id';

            my $cards = $stripe->get_cards(customer => $customer);
            isa_ok $cards, "Net::Stripe::List";
            is scalar @{$cards->data}, 1, 'customer has one card';
            my $card = @{$cards->data}[0];
            isa_ok $card, "Net::Stripe::Card";

            my $new_card = $stripe->post_card(
                customer => $customer,
                card => $token_id_visa,
            );
            isnt $new_card->id, $card->id, 'new card has different card id';

            $cards = $stripe->get_cards(customer => $customer);
            isa_ok $cards, "Net::Stripe::List";
            is scalar @{$cards->data}, 2, 'customer has two cards';
        }

        Add_card_for_customer_object_via_token_object: {
            my $customer = $stripe->post_customer(
                card => $token_id_visa,
            );
            isa_ok $customer, 'Net::Stripe::Customer', 'got back a customer';
            ok $customer->id, 'customer has an id';

            my $cards = $stripe->get_cards(customer => $customer);
            isa_ok $cards, "Net::Stripe::List";
            is scalar @{$cards->data}, 1, 'customer has one card';
            my $card = @{$cards->data}[0];
            isa_ok $card, "Net::Stripe::Card";

            my $new_token = $stripe->get_token( token_id => $token_id_visa );
            my $new_card = $stripe->post_card(
                customer => $customer,
                card => $new_token,
            );
            isnt $new_card->id, $card->id, 'new card has different card id';

            $cards = $stripe->get_cards(customer => $customer);
            isa_ok $cards, "Net::Stripe::List";
            is scalar @{$cards->data}, 2, 'customer has two cards';
        }

        Add_card_for_customer_id_via_token_id: {
            my $customer = $stripe->post_customer(
                card => $token_id_visa,
            );
            isa_ok $customer, 'Net::Stripe::Customer', 'got back a customer';
            ok $customer->id, 'customer has an id';

            my $cards = $stripe->get_cards(customer => $customer);
            isa_ok $cards, "Net::Stripe::List";
            is scalar @{$cards->data}, 1, 'customer has one card';
            my $card = @{$cards->data}[0];
            isa_ok $card, "Net::Stripe::Card";

            my $new_card = $stripe->post_card(
                customer => $customer->id,
                card => $token_id_visa,
            );
            isnt $new_card->id, $card->id, 'new card has different card id';

            $cards = $stripe->get_cards(customer => $customer);
            isa_ok $cards, "Net::Stripe::List";
            is scalar @{$cards->data}, 2, 'customer has two cards';
        }

        Add_source_for_customer_id_via_token_id: {
            my $customer = $stripe->post_customer(
                source => $token_id_visa,
            );

            my $cards = $stripe->get_cards(customer => $customer);
            isa_ok $cards, "Net::Stripe::List";
            is scalar @{$cards->data}, 1, 'customer has one card';
            my $card = @{$cards->data}[0];
            isa_ok $card, "Net::Stripe::Card";

            my $new_card = $stripe->post_card(
                customer => $customer->id,
                source => $token_id_visa,
            );
            isnt $new_card->id, $card->id, 'new card has different card id';

            $cards = $stripe->get_cards(customer => $customer);
            isa_ok $cards, "Net::Stripe::List";
            is scalar @{$cards->data}, 2, 'customer has two cards';
        }

        Add_card_for_customer_id_via_token_object: {
            my $customer = $stripe->post_customer(
                card => $token_id_visa,
            );
            isa_ok $customer, 'Net::Stripe::Customer', 'got back a customer';
            ok $customer->id, 'customer has an id';

            my $cards = $stripe->get_cards(customer => $customer);
            isa_ok $cards, "Net::Stripe::List";
            is scalar @{$cards->data}, 1, 'customer has one card';
            my $card = @{$cards->data}[0];
            isa_ok $card, "Net::Stripe::Card";

            my $new_token = $stripe->get_token( token_id => $token_id_visa );
            my $new_card = $stripe->post_card(
                customer => $customer->id,
                card => $new_token,
            );
            isnt $new_card->id, $card->id, 'new card has different card id';

            $cards = $stripe->get_cards(customer => $customer);
            isa_ok $cards, "Net::Stripe::List";
            is scalar @{$cards->data}, 2, 'customer has two cards';
        }

        Delete_card: {
            my $customer = $stripe->post_customer(
                card => $token_id_visa,
            );
            isa_ok $customer, 'Net::Stripe::Customer';

            my $cards = $stripe->get_cards( customer => $customer );
            isa_ok $cards, "Net::Stripe::List";
            my @cards = $cards->elements;
            is scalar( @cards ), 1, 'customer has one card';

            my $deleted = $stripe->delete_card(
                customer => $customer->id,
                card => $cards[0]->id,
            );
            ok $deleted->{deleted}, 'card is now deleted';

            $cards = $stripe->get_cards( customer => $customer );
            isa_ok $cards, "Net::Stripe::List";
            @cards = $cards->elements;
            is scalar( @cards ), 0, 'customer has zero cards';
        }

        Update_existing_card_for_customer_id: {
            my $customer = $stripe->post_customer(
                source => $token_id_visa,
            );
            isa_ok $customer, 'Net::Stripe::Customer', 'got back a customer';

            my $card_id = $customer->default_card;

            $stripe->update_card(
                customer_id => $customer->id,
                card_id => $card_id,
                card => $fake_card,
            );

            my $cards = $stripe->get_cards(
                customer => $customer->id,
            );
            isa_ok $cards, 'Net::Stripe::List', 'Card List object returned';
            is scalar @{$cards->data}, 1, 'customer only has one card';

            my $card = @{$cards->data}[0];
            isa_ok $card, 'Net::Stripe::Card';

            is $card->id, $card_id, 'card id matches';

# HACK, HACK, HACK!!
# the Stripe API has inconsistent responses for empty address_line2 when passing the empty string.
# on create, it correctly reflects the empty string, while on update it incorrectly reflects undef/null
my $fake_card = Storable::dclone( $fake_card );
undef( $fake_card->{address_line2} );

            for my $f (sort keys %{$fake_card}) {
                is_deeply $card->$f, $fake_card->{$f}, "card $f matches";
            }

            $stripe->update_card(
                customer_id => $customer->id,
                card_id => $card_id,
                card => $updated_fake_card,
            );

            $cards = $stripe->get_cards(
                customer => $customer->id,
            );
            isa_ok $cards, 'Net::Stripe::List', 'Card List object returned';
            is scalar @{$cards->data}, 1, 'customer still only has one card';

            $card = @{$cards->data}[0];
            is $card->id, $card_id, "card id still matches";

# HACK, HACK, HACK!!
# the Stripe API has inconsistent responses for empty address_line2 when passing the empty string.
# on create, it correctly reflects the empty string, while on update it incorrectly reflects undef/null
my $update_fake_card = Storable::dclone( $updated_fake_card );
undef( $updated_fake_card->{address_line2} );

            for my $f (sort keys %$updated_fake_card) {
                if ( ref( $updated_fake_card->{$f} ) eq 'HASH' ) {
                    my $merged = { %{$fake_card->{$f} || {}}, %{$updated_fake_card->{$f} || {}} };
                    is_deeply $card->$f, $merged, "updated card $f matches";
                } else {
                    is $card->$f, $updated_fake_card->{$f}, "updated card $f matches";
                }
            }
        }

        Set_default_source: {
            my $source = $stripe->create_source(
                type => 'card',
                token => $token_id_visa,
            );
            isa_ok $source, 'Net::Stripe::Source';
            my $customer = $stripe->post_customer(
                source => $source->id,
            );
            isa_ok $customer, 'Net::Stripe::Customer';
            my $customer_id = $customer->id;
            my $default_source_id = $customer->default_source;

            my $sources = $stripe->list_sources(
                customer_id => $customer->id,
                object => 'source',
            );
            isa_ok $sources, "Net::Stripe::List";
            my @sources = $sources->elements;
            is scalar( @sources ), 1, 'customer only has one card';
            is $sources[0]->id, $default_source_id, 'default_source matches';

            my $new_source = $stripe->create_source(
                type => 'card',
                token => $token_id_visa,
            );
            isa_ok $new_source, 'Net::Stripe::Source';
            $stripe->attach_source(
                customer_id => $customer_id,
                source_id => $new_source->id,
            );
            $sources = $stripe->list_sources(
                customer_id => $customer->id,
                object => 'source',
            );
            isa_ok $sources, "Net::Stripe::List";
            @sources = $sources->elements;
            is scalar( @sources ), 2, 'customer now has two cards';
            isnt $new_source->id, $sources[0]->id, 'new source has different source id';

            $customer = $stripe->get_customer(
                customer_id => $customer_id,
            );
            isa_ok $customer, 'Net::Stripe::Customer';
            is $customer->default_source, $default_source_id, 'default_source unchanged';

            $customer = $stripe->post_customer(
                customer => $customer_id,
                default_source => $new_source->id,
            );

            $customer = $stripe->get_customer(
                customer_id => $customer_id,
            );
            isa_ok $customer, 'Net::Stripe::Customer';
            is $customer->default_source, $new_source->id, 'default_source matches new source';
            isnt $customer->default_source, $default_source_id, 'default_source changed';
        }

        Set_default_card: {
            my $customer = $stripe->post_customer(
                card => $token_id_visa,
            );
            isa_ok $customer, 'Net::Stripe::Customer';
            my $customer_id = $customer->id;
            my $default_card_id = $customer->default_card;

            my $cards = $stripe->get_cards( customer => $customer_id );
            isa_ok $cards, "Net::Stripe::List";
            my @cards = $cards->elements;
            is scalar( @cards ), 1, 'customer only has one card';
            is $cards[0]->id, $default_card_id, 'default_card matches';

            my $new_card = $stripe->post_card(
                customer => $customer_id,
                card => $token_id_visa,
            );
            isa_ok $new_card, 'Net::Stripe::Card';
            $cards = $stripe->get_cards( customer => $customer_id );
            isa_ok $cards, "Net::Stripe::List";
            @cards = $cards->elements;
            is scalar( @cards ), 2, 'customer now has two cards';
            isnt $new_card->id, $cards[0]->id, 'new card has different card id';

            $customer = $stripe->get_customer(
                customer_id => $customer_id,
            );
            isa_ok $customer, 'Net::Stripe::Customer';
            is $customer->default_card, $default_card_id, 'default_card unchanged';

            $customer = $stripe->post_customer(
                customer => $customer_id,
                default_card => $new_card->id,
            );

            $customer = $stripe->get_customer(
                customer_id => $customer_id,
            );
            isa_ok $customer, 'Net::Stripe::Customer';
            is $customer->default_card, $new_card->id, 'default_card matches new card';
            isnt $customer->default_card, $default_card_id, 'default_card changed';
        }

        Customers_with_plans: {
            my $free_product = $stripe->create_product(
                name => "Freeservice $future_ymdhms",
                type => 'service',
            );
            my $freeplan = $stripe->post_plan(
                id => "free-$future_ymdhms",
                amount => 0,
                currency => 'usd',
                interval => 'year',
                product => $free_product->id,
            );
            ok $freeplan->id, 'freeplan created';
            my $customer = $stripe->post_customer(
                plan => $freeplan->id,
            );
            is $customer->subscription->plan->id, $freeplan->id,
                'customer has freeplan';

            # Now update subscription of an existing customer
            my $other = $stripe->post_customer();
            my $subs = $stripe->post_subscription(
                customer => $other->id,
                plan => $freeplan->id,
            );
            isa_ok $subs, 'Net::Stripe::Subscription',
                'got a subscription back';
            is $subs->plan->id, $freeplan->id, 'plan id matches';

            my $subs_again = $stripe->get_subscription(
                customer => $other->id
            );
            is $subs_again->status, 'active', 'subs is active';
            is $subs_again->start, $subs->start, 'same subs was returned';

            # Now cancel subscriptions
            my $dsubs = $stripe->delete_subscription(
                customer => $customer->id,
                subscription => $customer->subscription->id,
            );
            is $dsubs->status, 'canceled', 'subscription is canceled';
            ok $dsubs->canceled_at, 'has canceled_at';
            ok $dsubs->ended_at, 'has ended_at';

            my $other_dsubs = $stripe->post_subscription(
                customer => $other->id,
                subscription => $subs_again->id,
                cancel_at_period_end => 1,
            );
            is $other_dsubs->status, 'active', 'subscription is still active';
            ok $other_dsubs->canceled_at, 'has canceled_at';
            ok !$other_dsubs->ended_at, 'does not have ended_at (not at period end yet)';
            ok $other_dsubs->cancel_at_period_end, 'cancel_at_period_end';

            my $pricey_product = $stripe->create_product(
                name => "Priceyservice $future_ymdhms",
                type => 'service',
            );
            my $priceyplan = $stripe->post_plan(
                id => "pricey-$future_ymdhms",
                amount => 1000,
                currency => 'usd',
                interval => 'year',
                product => $pricey_product->id,
            );
            ok $priceyplan->id, 'priceyplan created';
            my $coupon_id = "priceycoupon-$future_ymdhms";
            my $coupon = $stripe->post_coupon(
                id => $coupon_id,
                percent_off => 100,
                duration => 'once',
                max_redemptions => 2,
                redeem_by => time() + 100,
            );
            isa_ok $coupon, 'Net::Stripe::Coupon',
                'I love it when a coupon pays for the first month';
            is $coupon->id, $coupon_id, 'coupon id is the same';

            $customer->coupon($coupon->id);
            $stripe->post_customer(customer => $customer);
            $customer = $stripe->get_customer(customer_id => $customer->id);
            is $customer->discount->coupon->id, $coupon_id,
              'got the coupon';
            my $delete_resp = $stripe->delete_customer_discount(customer => $customer);
            ok $delete_resp->{deleted}, 'stripe reports discount deleted';
            $customer = $stripe->get_customer(customer_id => $customer->id);
            ok !$customer->discount, 'customer really has no discount';

            my $coupon_assign_epoch = time;
            $customer->coupon($coupon->id);
            $stripe->post_customer(customer => $customer);
            $customer = $stripe->get_customer(customer_id => $customer->id);
            is $customer->discount->coupon->id, $coupon_id,
              'got the coupon';
            ok $coupon_assign_epoch - 10 <= $customer->discount->start,
              'discount started on or after coupon assignment (give or take 10 seconds)';
            ok $customer->discount->start <= time + 10,
              'discount has started (give or take 10 seconds)';
            my $priceysubs = $stripe->post_subscription(
                customer => $customer->id,
                plan => $priceyplan->id,
            );
            isa_ok $priceysubs, 'Net::Stripe::Subscription',
                'got a subscription back';
            is $priceysubs->plan->id, $priceyplan->id, 'plan id matches';
            $customer = $stripe->get_customer(customer_id => $customer->id);
            is $customer->subscriptions->get(0)->plan->id,
              $priceyplan->id, 'subscribed without a creditcard';

            # Test ability to add, retrieve lists of subscriptions, since we can now have > 1
            my $subs_list = $stripe->list_subscriptions(customer => $customer);
            isa_ok $subs_list, 'Net::Stripe::List', 'Subscription List object returned';
            is scalar @{$subs_list->data}, 1, 'Customer has one subscription';

            $subs = $stripe->post_subscription(
                customer => $customer->id,
                plan => $freeplan->id,
            );
            $subs_list = $stripe->list_subscriptions(customer => $customer);
            is scalar @{$subs_list->data}, 2, 'Customer now has two subscriptions';
        }
    }
}

Invoices_and_items: {
    Successful_usage: {
        my $product = $stripe->create_product(
            name => "Service $future_ymdhms",
            type => 'service',
        );
        my $plan = $stripe->post_plan(
            id => "plan-$future_ymdhms",
            amount => 1000,
            currency => 'usd',
            interval => 'year',
            product => $product->id,
        );
        ok $plan->id, 'plan has an id';
        my $customer = $stripe->post_customer(
            source => $token_id_visa,
            plan => $plan->id,
        );
        ok $customer->id, 'customer has an id';
        is $customer->subscription->plan->id, $plan->id, 'customer has a plan';
        
        my $ChargesList = $stripe->get_charges(limit => 1);
        my $charge = @{$ChargesList->data}[0];
        ok $charge->invoice, "Charge created by Subscription sign-up has an Invoice ID";

        my $item = $stripe->create_invoiceitem(
            customer => $customer->id,
            amount   => 700,
            currency => 'usd',
            description => 'Pickles',
        );
        for my $f (qw/date description currency amount id/) {
            ok $item->$f, "item has $f";
        }

        my $sameitem = $stripe->get_invoiceitem(invoice_item => $item->id );
        is $sameitem->id, $item->id, 'get item returns same id';

        $item->description('Jerky');
        my $newitem = $stripe->post_invoiceitem(invoice_item => $item);
        is $newitem->id, $item->id, 'item id is unchanged';
        is $newitem->currency, $item->currency, 'item currency unchanged';
        is $newitem->description, $item->description, 'item desc changed';

        my $items = $stripe->get_invoiceitems(
            customer => $customer->id,
            limit => 1,
        );
        is scalar(@{$items->data}), 1, 'only 1 item returned';
        is $items->get(0)->id, $item->id, 'item id is correct';


        my $invoice = $stripe->get_upcominginvoice($customer->id);
        isa_ok $invoice, 'Net::Stripe::Invoice';
        is $invoice->customer, $customer->id, 'invoice customer id matches';
        is $invoice->{subtotal}, 1700, 'subtotal';
        is $invoice->{total}, 1700, 'total';
        is scalar(@{ $invoice->lines->data }), 2, '2 lines';

        my $all_invoices = $stripe->get_invoices(
            customer => $customer->id,
            limit    => 1,
        );
        is scalar(@{$all_invoices->data}), 1, 'one invoice returned';

        # We can't fetch the upcoming invoice because it does not have an ID
        # So to test get_invoice() we need a way to create an invoice.
        # This test should be re-written in a way that works reliably.
        # my $same_invoice = $stripe->get_invoice($invoice->id);
        # is $same_invoice->id, $invoice->id, 'invoice id matches';

        my $resp = $stripe->delete_invoiceitem(invoice_item => $item->id);
        is $resp->{deleted}, '1', 'invoiceitem deleted';
        is $resp->{id}, $item->id, 'deleted id is correct';

        eval {
            # swallow the expected warning rather than have it print out during tests.
            local $SIG{__WARN__} = sub {};
            $stripe->get_invoiceitem(invoice_item => $item->id);
        };
        like $@, qr/invalid_request_error.*resource_missing/s, 'correct error message';
    }
}

Boolean_Query_Args: {
    my $subscription = Net::Stripe::Subscription->new(
        prorate => 0,
        plan => "freeplan",
    );
    isa_ok $subscription, 'Net::Stripe::Subscription',
        'got a subscription back';
    throws_ok {
        $subscription->is_a_boolean();
    } qr/Expected 1 parameter/, 'no parameters to is_a_boolean()';
    throws_ok {
        $subscription->is_a_boolean({});
    } qr/Reference \{\} did not pass type constraint "Str"/, 'non-string parameter to is_a_boolean()';
    throws_ok {
        $subscription->get_form_field_value();
    } qr/Expected 1 parameter/, 'no parameters to get_form_field_value()';
    throws_ok {
        $subscription->get_form_field_value({});
    } qr/Reference \{\} did not pass type constraint "Str"/, 'non-string parameter to get_form_field_value()';
    throws_ok {
        $subscription->get_form_field_value( 'invalid_field' );
    } qr/Can't locate object method "invalid_field"/, 'invalid form field';
    ok !$subscription->is_a_boolean( 'plan' ), 'plan is not a boolean';
    is $subscription->get_form_field_value( 'plan' ), 'freeplan',
        "plan form value is 'freeplan'";
    ok $subscription->is_a_boolean( 'prorate' ), 'prorate is a boolean';
    is $subscription->prorate, 0, 'prorate matches zero';
    is $subscription->get_form_field_value( 'prorate' ), 'false',
        "prorate form value is 'false'";
    $subscription->prorate(1);
    is $subscription->prorate, 1, 'prorate matches one';
    is $subscription->get_form_field_value( 'prorate' ), 'true',
        "prorate form value is 'true'";
}

done_testing();
