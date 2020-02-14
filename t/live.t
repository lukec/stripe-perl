#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warn;
use Net::Stripe;
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


# set future date to one year plus one month, since adding only one year
# currently matches default token expiration date, preventing us from
# discerning between the default expiration date and any expiration date
# that we are explicitly testing the setting of
my $future = DateTime->now + DateTime::Duration->new(months=> 1, years => 1);
my $future_ymdhms = $future->ymd('-') . '-' . $future->hms('-');

my $future_future = $future + DateTime::Duration->new(years => 1);

my $stripe = Net::Stripe->new(api_key => $API_KEY, debug => 1);
isa_ok $stripe, 'Net::Stripe', 'API object created today';

my $fake_card = {
    exp_month => $future->month,
    exp_year  => $future->year,
    name      => 'Anonymous',
    metadata  => {
        'somecardmetadata' => 'testing, testing, 1-2-3',
    },
    address_line1   => '123 Main Street',
    address_city    => 'Anytown',
    address_state   => 'Anystate',
    address_zip     => '55555',
    address_country => 'US',
};

my $updated_fake_card = {
    exp_month       => $future_future->month,
    exp_year        => $future_future->year,
    name            => 'Dr. Anonymous',
    metadata  => {
        'somenewcardmetadata' => 'can you hear me now?',
    },
    address_line1   => '321 Easy Street',
    address_city    => 'Beverly Hills',
    address_state   => 'California',
    address_zip     => '90210',
    address_country => 'US',
};

# passing a test token id to get_token() retrieves a token object with a card
# that has the same card number, based on the test token passed, but it has a
# unique card id each time, which is sufficient for the behaviors we are testing
my $token_id_visa = 'tok_visa';

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
        throws_ok { $constraint->assert_valid( $invalid ) } qr/Value '$invalid' must be a $object id string of the form $prefix\.\+/, 'invalid source id';
    }
}

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

Plans: {
    Basic_successful_use: {
        # Notice that the plan ID requires uri escaping
        my $id = $future_ymdhms;
        my %plan_args = (
            id => $id,
            amount => 0,
            currency => 'usd',
            interval => 'month',
            name => "Test Plan - $future",
            trial_period_days => 10,
            statement_descriptor => 'Statement Descr',
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
                card => $token_id_visa,
                description => 'Wikileaks donation',
                statement_descriptor => 'Statement Descr',
            );
        } 'Created a charge object';
        isa_ok $charge, 'Net::Stripe::Charge';
        for my $field (qw/id amount created currency description
                          livemode paid refunded status statement_descriptor/) {
            ok defined($charge->$field), "charge has $field";
        }
        ok !$charge->refunded, 'charge is not refunded';
        ok $charge->paid, 'charge was paid';
        like $charge->status, qr/^(?:paid|succeeded)$/, 'charge was successful';
        ok $charge->captured, 'charge was captured';
        is $charge->statement_descriptor, 'Statement Descr', 'charge statement_descriptor matches';

        # Check out the returned card object
        my $card = $charge->card;
        isa_ok $card, 'Net::Stripe::Card';

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
                card => 'tok_avsLine1Fail',
                description => 'Wikileaks donation',
            );
        } 'Created a charge object';
        isa_ok $charge, 'Net::Stripe::Charge';

        # Check out the returned card object
        $card = $charge->card;
        isa_ok $card, 'Net::Stripe::Card';
        is $card->address_line1_check, 'fail', 'card address_line1_check';
    }

    Charge_with_metadata: {
        my $charge;
        lives_ok {
            $charge = $stripe->post_charge(
                amount => 2500,
                currency => 'usd',
                card => $token_id_visa,
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
                card => $token->card->id,
            );
        };
        if ($@) {
            my $e = $@;
            isa_ok $e, 'Net::Stripe::Error', 'error raised is an object';
            is $e->type, 'post_charge error', 'error type';
            like $e->message, qr/^Invalid value 'card_.+' passed for parameter 'card'\. Charges without an existing customer can only accept a token id\.$/, 'error message';
        } else {
            fail 'post charge with card id';
        }
    }

    Post_charge_for_customer_id_with_attached_card: {
        my $customer = $stripe->post_customer(
            card => $token_id_visa,
        );
        my $charge = $stripe->post_charge(
            amount => 100,
            currency => 'usd',
            customer => $customer->id,
        );
        isa_ok $charge, 'Net::Stripe::Charge';
        ok $charge->paid, 'charge was paid';
        like $charge->status, qr/^(?:paid|succeeded)$/, 'charge was successful';
        is $charge->card->id, $customer->default_card, 'charged default card';
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
                card => $token_id_visa,
            );
        };
        if ($@) {
            my $e = $@;
            isa_ok $e, 'Net::Stripe::Error', 'error raised is an object';
            is $e->type, 'post_charge error', 'error type';
            like $e->message, qr/^Invalid value 'tok_.+' passed for parameter 'card'\. Charges for an existing customer can only accept a card id\.$/, 'error message';
        } else {
            fail 'post charge for customer with token id';
        }
    }

    Post_charge_for_customer_id_using_card_id: {
        # customer may have multiple cards. allow ability to select a specific
        # card for a given charge.
        my $customer = $stripe->post_customer();
        my $card = $stripe->post_card(
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
        my $charge = $stripe->post_charge(
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
            fail 'missing card and customer';
        }

        # Test an invalid currency
        eval {
            $stripe->post_charge(
                amount => 3300,
                currency => 'zzz',
                card => $token_id_visa,
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
                card => $token_id_visa,
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
                card => $token_id_visa,
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
                card => $token_id_visa,
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
            for my $f (qw/card coupon email description plan trial_end/) {
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
            $stripe->post_customer(customer => $customer);
            $cards = $stripe->get_cards(customer => $customer);
            isa_ok $cards, "Net::Stripe::List";
            is scalar @{$cards->data}, 1, 'customer still has one card';
            my $new_card = @{$cards->data}[0];
            isnt $new_card->id, $card->id, 'new card has different card id';
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
                card => $token_id_visa,
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

            for my $f (sort keys %$updated_fake_card) {
                if ( ref( $updated_fake_card->{$f} ) eq 'HASH' ) {
                    my $merged = { %{$fake_card->{$f} || {}}, %{$updated_fake_card->{$f} || {}} };
                    is_deeply $card->$f, $merged, "updated card $f matches";
                } else {
                    is $card->$f, $updated_fake_card->{$f}, "updated card $f matches";
                }
            }
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
            my $freeplan = $stripe->post_plan(
                id => "free-$future_ymdhms",
                amount => 0,
                currency => 'usd',
                interval => 'year',
                name => "Freeplan $future_ymdhms",
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

            my $other_dsubs = $stripe->delete_subscription(
                customer => $other->id,
                subscription => $subs_again->id,
                at_period_end => 1,
            );
            is $other_dsubs->status, 'active', 'subscription is still active';
            ok $other_dsubs->canceled_at, 'has canceled_at';
            ok !$other_dsubs->ended_at, 'does not have ended_at (not at period end yet)';

            my $priceyplan = $stripe->post_plan(
                id => "pricey-$future_ymdhms",
                amount => 1000,
                currency => 'usd',
                interval => 'year',
                name => "Priceyplan $future_ymdhms",
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
        my $plan = $stripe->post_plan(
            id => "plan-$future_ymdhms",
            amount => 1000,
            currency => 'usd',
            interval => 'year',
            name => "Plan $future_ymdhms",
        );
        ok $plan->id, 'plan has an id';
        my $customer = $stripe->post_customer(
            card => $token_id_visa,
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
