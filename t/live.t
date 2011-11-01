#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Test::Exception;
use Net::Stripe;
use DateTime;
use DateTime::Duration;

my $API_KEY = $ENV{STRIPE_API_KEY};
unless ($API_KEY) {
    plan skip_all => "No STRIPE_API_KEY env var is defined.";
    exit;
}

my $future = DateTime->now + DateTime::Duration->new(years => 1);
my $future_ymdhms = $future->ymd('-') . '-' . $future->hms('-');
my $stripe = Net::Stripe->new(api_key => $API_KEY, debug => 1);
isa_ok $stripe, 'Net::Stripe', 'API object created today';

my $fake_card = {
    number    => '4242-4242-4242-4242',
    exp_month => $future->month,
    exp_year  => $future->year,
    cvc       => 123,
    name      => 'Anonymous',
};

Card_Tokens: {
    Basic_successful_use: {
        my $token = $stripe->post_token(
            card => $fake_card,
            amount => 330,
            currency => 'usd',
        );
        isa_ok $token, 'Net::Stripe::Token', 'got a token back';
        is $token->card->last4, '4242', 'token card';
        is $token->amount, 330, 'token amount';
        is $token->currency, 'usd', 'token currency';
        ok !$token->used, 'token is not used';

        my $same = $stripe->get_token($token->id);
        isa_ok $token, 'Net::Stripe::Token', 'got a token back';
        is $same->id, $token->id, 'token id matches';


        my $no_amount = $stripe->post_token( card => $fake_card );
        isa_ok $no_amount, 'Net::Stripe::Token', 'got a token back';
        is $no_amount->card->last4, '4242', 'token card';
        is $no_amount->amount, 0, 'card has no amount';
        is $no_amount->currency, 'usd', 'token currency';
        ok !$no_amount->used, 'token is not used';
    }
}

Plans: {
    Basic_successful_use: {
        # Notice that the plan ID requires uri escaping
        my $id = $future_ymdhms;
        my $plan = $stripe->post_plan(
            id => $id,
            amount => 0,
            currency => 'usd',
            interval => 'month',
            name => "Test Plan - $future",
            trial_period_days => 10,
        );
        isa_ok $plan, 'Net::Stripe::Plan',
            'I love it when a plan comes together';

        my $newplan = $stripe->get_plan($id);
        isa_ok $newplan, 'Net::Stripe::Plan',
            'I love it when another plan comes together';
        is $newplan->id, $id, 'Plan id was encoded correctly';
        is($newplan->$_, $plan->$_, "$_ matches")
            for qw/id amount currency interval name trial_period_days/;

        my $plans = $stripe->get_plans(count => 1);
        is scalar(@$plans), 1, 'got just one plan';
        is $plans->[0]->id, $id, 'plan id matches';

        my $hash = $stripe->delete_plan($plan);
        ok $hash->{deleted}, 'delete response indicates delete was successful';
        eval { $stripe->get_plan($id) };
        ok $@, "no longer can fetch deleted plans";
    }
}

Coupons: {
    Basic_successful_use: {
        my $id = "coupon-$future_ymdhms";
        my $coupon = $stripe->post_coupon(
            id => $id,
            percent_off => 50,
            duration => 'repeating',
            duration_in_months => 3,
            max_redemptions => 5,
            redeem_by => time() + 100,
        );
        isa_ok $coupon, 'Net::Stripe::Coupon',
            'I love it when a coupon comes together';
        is $coupon->id, $id, 'coupon id is the same';

        my $newcoupon = $stripe->get_coupon($id);
        isa_ok $newcoupon, 'Net::Stripe::Coupon',
            'I love it when another coupon comes together';
        is $newcoupon->id, $id, 'coupon id was encoded correctly';
        is($newcoupon->$_, $coupon->$_, "$_ matches")
            for qw/id percent_off duration duration_in_months 
                   max_redemptions redeem_by/;

        my $coupons = $stripe->get_coupons(count => 1);
        is scalar(@$coupons), 1, 'got just one coupon';
        is $coupons->[0]->id, $id, 'coupon id matches';

        my $hash = $stripe->delete_coupon($coupon);
        ok $hash->{deleted}, 'delete response indicates delete was successful';
        eval { $stripe->get_coupon($id) };
        ok $@, "no longer can fetch deleted coupons";
    }
}

Charges: {
    Basic_successful_use: {
        my $charge;
        lives_ok { 
            $charge = $stripe->post_charge(
                amount => 3300,
                currency => 'usd',
                card => $fake_card,
                description => 'Wikileaks donation',
            );
        } 'Created a charge object';
        isa_ok $charge, 'Net::Stripe::Charge';
        for my $field (qw/id amount created currency description fee
                          livemode paid refunded/) {
            ok defined($charge->$field), "charge has $field";
        }
        ok !$charge->refunded, 'charge is not refunded';
        ok $charge->paid, 'charge was paid';

        # Check out the returned card object
        my $card = $charge->card;
        isa_ok $card, 'Net::Stripe::Card';
        is $card->country, 'US', 'card country';
        is $card->exp_month, $future->month, 'card exp_month';
        is $card->exp_year,  $future->year, 'card exp_year';
        is $card->last4, '4242', 'card last4';
        is $card->type, 'Visa', 'card type';
        is $card->cvc_check, 'pass', 'card cvc_check';

        # Fetch a charge
        my $charge2;
        lives_ok { $charge2 = $stripe->get_charge($charge->id) }
            'Fetching a charge works';
        is $charge2->id, $charge->id, 'Charge ids match';

        # Refund a charge
        my $charge3;
        lives_ok { $charge = $stripe->refund_charge($charge->id) }
            'Refunding a charge works';
        is $charge->id, $charge->id, 'returned charge object matches id';
        ok $charge->refunded, 'charge is refunded';
        ok $charge->paid, 'charge was paid';

        # Fetch list of charges
        my $charges = $stripe->get_charges( count => 1 );
        is scalar(@$charges), 1, 'one charge returned';
        is $charges->[0]->id, $charge->id, 'charge ids match';
    }

    Post_charge_using_customer: {
        my $token = $stripe->post_token( card => $fake_card );
        my $customer = $stripe->post_customer( card => $token->id );
        my $charge = $stripe->post_charge(
            customer => $customer->id,
            amount => 250,
            currency => 'usd',
        );
        isa_ok $charge, 'Net::Stripe::Charge';
        ok $charge->paid, 'charge was paid';
    }

    Post_charge_using_token: {
        my $token = $stripe->post_token( card => $fake_card );
        my $charge = $stripe->post_charge(
            amount => 100,
            currency => 'usd',
            card => $token->id,
        );
        isa_ok $charge, 'Net::Stripe::Charge';
        ok $charge->paid, 'charge was paid';
    }

    Rainy_day: {
        throws_ok {
            $stripe->post_charge(
                amount => 3300,
                currency => 'usd',
                description => 'Wikileaks donation',
            );
        } qr/invalid_request_error/, 'missing card and customer';

        throws_ok {
            $stripe->post_charge(
                amount => 3300,
                currency => 'usd',
                description => 'Wikileaks donation',
                customer => 'fake-customer-id',
                card => {
                    number => '4242-4242-4242-4242',
                    exp_month => $future->month,
                    exp_year  => $future->year,
                    cvc => 123,
                    name => 'Anonymous',
                },
            );
        } qr/invalid_request_error/, 'missing card and customer';

        # Test an invalid currency
        eval {
            $stripe->post_charge(
                amount => 3300,
                currency => 'zzz',
                card => {
                    number => '4242-4242-4242-4242',
                    exp_month => $future->month,
                    exp_year  => $future->year,
                    cvc => 123,
                },
            );
        };
        if ($@) {
            my $e = $@;
            isa_ok $e, 'Net::Stripe::Error', 'error raised is an object';
            is $e->type, 'invalid_request_error', 'error type';
            is $e->message, 'Invalid currency: zzz', 'error message';
            is $e->param, 'currency', 'error param';
        }
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
            my $samesy = $stripe->post_customer($customer);
            is $samesy->description, $customer->description,
                'post_customer returns an updated customer object';
            my $same = $stripe->get_customer($id);
            is $same->description, $customer->description,
                'get customer retrieves an updated customer';

            # Fetch the list of customers
            my $all = $stripe->get_customers(count => 1);
            is scalar(@$all), 1, 'only one customer returned';
            is $all->[0]->id, $customer->id, 'correct customer returned';

            # Delete a customer
            $stripe->delete_customer($customer);
            $customer = $stripe->get_customer($id);
            ok $customer->deleted, 'customer is now deleted';
        }

        Create_with_all_the_works: {
            my $customer = $stripe->post_customer(
                card => $fake_card,
                email => 'stripe@example.com',
                description => 'Test for Net::Stripe',
            );
            my $card = $customer->active_card;
            isa_ok $card, 'Net::Stripe::Card';
            is $card->country, 'US', 'card country';
            is $card->exp_month, $future->month, 'card exp_month';
            is $card->exp_year,  $future->year, 'card exp_year';
            is $card->last4, '4242', 'card last4';
            is $card->type, 'Visa', 'card type';
        }

        Create_with_a_token: {
            my $token = $stripe->post_token(card => $fake_card);
            my $customer = $stripe->post_customer(
                card => $token->id,
            );
            isa_ok $customer, 'Net::Stripe::Customer', 'got back a customer';
            ok $customer->id, 'customer has an id';
            is $customer->active_card->last4, '4242', 'card token ok';
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
                customer_id => $other->id,
                plan => $freeplan->id,
            );
            isa_ok $subs, 'Net::Stripe::Subscription',
                'got a subscription back';
            is $subs->plan->id, $freeplan->id;

            my $subs_again = $stripe->get_subscription(
                customer_id => $other->id,
            );
            is $subs_again->status, 'active', 'subs is active';
            is $subs_again->start, $subs->start, 'same subs was returned';

            # Now cancel subscriptions
            my $dsubs = $stripe->delete_subscription(
                customer_id => $customer->id,
            );
            is $dsubs->status, 'canceled', 'subscription is canceled';
            ok $dsubs->canceled_at, 'has canceled_at';
            ok $dsubs->ended_at, 'has ended_at';

            my $other_dsubs = $stripe->delete_subscription(
                customer_id => $other->id,
                at_period_end => 1,
            );
            is $other_dsubs->status, 'active', 'subscription is still active';
            ok $other_dsubs->canceled_at, 'has canceled_at';
            ok $other_dsubs->ended_at, 'has ended_at';
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
        my $token = $stripe->post_token(card => $fake_card);
        ok $token->id, 'token has an id';
        my $customer = $stripe->post_customer(
            card => $token,
            plan => $plan->id,
        );
        ok $customer->id, 'customer has an id';
        is $customer->subscription->plan->id, $plan->id, 'customer has a plan';
        is $customer->active_card->last4, $token->card->last4,
            'customer has a card';

        my $item = $stripe->post_invoiceitem(
            customer => $customer->id,
            amount   => 700,
            currency => 'usd',
            description => 'Pickles',
        );
        for my $f (qw/date description currency amount id/) {
            ok $item->$f, "item has $f";
        }

        my $sameitem = $stripe->get_invoiceitem( $item->id );
        is $sameitem->id, $item->id, 'get item returns same id';

        $item->description('Jerky');
        my $newitem = $stripe->post_invoiceitem($item);
        is $newitem->id, $item->id, 'item id is unchanged';
        is $newitem->description, $item->description, 'item desc changed';

        my $items = $stripe->get_invoiceitems(
            customer => $customer->id,
            count => 1,
            offset => 0,
        );
        is scalar(@$items), 1, 'only 1 item returned';
        is $items->[0]->id, $item->id, 'item id is correct';


        my $invoice = $stripe->get_upcominginvoice($customer->id);
        isa_ok $invoice, 'Net::Stripe::Invoice';
        is $invoice->{subtotal}, 1700, 'subtotal';
        is $invoice->{total}, 1700, 'total';
        is scalar(@{ $invoice->lines }), 2, '2 lines';

        my $all_invoices = $stripe->get_invoices(
            customer => $customer->id,
            count    => 1,
            offset   => 0,
        );
        is scalar(@$all_invoices), 1, 'one invoice returned';

        # We can't fetch the upcoming invoice because it does not have an ID
        # So to test get_invoice() we need a way to create an invoice.
        # This test should be re-written in a way that works reliably.
        # my $same_invoice = $stripe->get_invoice($invoice->id);
        # is $same_invoice->id, $invoice->id, 'invoice id matches';

        my $resp = $stripe->delete_invoiceitem( $item->id );
        is $resp->{deleted}, 'true', 'invoiceitem deleted';
        is $resp->{id}, $item->id, 'deleted id is correct';

        eval { $stripe->get_invoiceitem($item->id) };
        like $@, qr/No such invoiceitem/, 'correct error message';
    }
}

done_testing();
