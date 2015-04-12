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

        {
            my $token = Net::Stripe::Token->new( card => $fake_card );
            isa_ok $token, 'Net::Stripe::Token', 'got a token back';
        }

        my $token = $stripe->post_token( card => $fake_card );
        isa_ok $token, 'Net::Stripe::Token', 'got a token back from post';

        is $token->card->last4, '4242', 'token card';
        ok !$token->used, 'token is not used';

        my $same = $stripe->get_token(token_id => $token->id);
        isa_ok $token, 'Net::Stripe::Token', 'got a token back';
        is $same->id, $token->id, 'token id matches';


        my $no_amount = $stripe->post_token( card => $fake_card );
        isa_ok $no_amount, 'Net::Stripe::Token', 'got a token back';
        is $no_amount->card->last4, '4242', 'token card';
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

        my $newplan = $stripe->get_plan(plan_id => $id);
        isa_ok $newplan, 'Net::Stripe::Plan',
            'I love it when another plan comes together';
        is $newplan->id, $id, 'Plan id was encoded correctly';
        is($newplan->$_, $plan->$_, "$_ matches")
            for qw/id amount currency interval name trial_period_days/;

        my $plans = $stripe->get_plans(limit => 1);
        is scalar(@{$plans->data}), 1, 'got just one plan';
        is $plans->get(0)->id, $id, 'plan id matches';
        is $plans->last->id, $id, 'plan id matches';

        my $hash = $stripe->delete_plan($plan);
        ok $hash->{deleted}, 'delete response indicates delete was successful';
        # swallow the expected warning rather than have it print out durring tests.
        close STDERR;
        open(STDERR, ">", "/dev/null");
        eval { $stripe->get_plan(plan_id => $id) };
        ok $@, "no longer can fetch deleted plans";
        close STDERR;
        open(STDERR, ">&", STDOUT);
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

        my $newcoupon = $stripe->get_coupon(coupon_id => $id);
        isa_ok $newcoupon, 'Net::Stripe::Coupon',
            'I love it when another coupon comes together';
        is $newcoupon->id, $id, 'coupon id was encoded correctly';
        is($newcoupon->$_, $coupon->$_, "$_ matches")
            for qw/id percent_off duration duration_in_months
                   max_redemptions redeem_by/;

        my $coupons = $stripe->get_coupons(limit => 1);
        is scalar(@{$coupons->data}), 1, 'got just one coupon';
        is $coupons->get(0)->id, $id, 'coupon id matches';

        my $hash = $stripe->delete_coupon($coupon);
        ok $hash->{deleted}, 'delete response indicates delete was successful';
        # swallow the expected warning rather than have it print out durring tests.
        close STDERR;
        open(STDERR, ">", "/dev/null");
        eval { $stripe->get_coupon(coupon_id => $id) };
        ok $@, "no longer can fetch deleted coupons";
        close STDERR;
        open(STDERR, ">&", STDOUT);
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
        for my $field (qw/id amount created currency description
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
        is $card->brand, 'Visa', 'card brand';
        is $card->cvc_check, 'pass', 'card cvc_check';

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
        is $refund->charge, $charge->id, 'returned charge object matches id';
        is $refund->amount, 1000, 'partial refund $10';
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
    }

    Charge_with_metadata: {
        my $charge;
        lives_ok {
            $charge = $stripe->post_charge(
                amount => 2500,
                currency => 'usd',
                card => $fake_card,
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
        # swallow the expected warning rather than have it print out durring tests.
        close STDERR;
        open(STDERR, ">", "/dev/null");

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
            like $e->message, '/^Invalid currency: zzz/', 'error message';
            is $e->param, 'currency', 'error param';
        }
        close STDERR;
        open(STDERR, ">&", STDOUT);
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
        }

        Create_with_all_the_works: {
            my $customer = $stripe->post_customer(
                card => $fake_card,
                email => 'stripe@example.com',
                description => 'Test for Net::Stripe',
                metadata => {'somemetadata' => 'hello world'},
            );
            my $path = 'customers/'.$customer->id.'/cards/'.$customer->default_card;
            my $card = $stripe->_get( $path );
            isa_ok $card, 'Net::Stripe::Card';
            is $card->country, 'US', 'card country';
            is $card->exp_month, $future->month, 'card exp_month';
            is $card->exp_year,  $future->year, 'card exp_year';
            is $card->last4, '4242', 'card last4';
            is $card->brand, 'Visa', 'card brand';
            is $customer->metadata->{'somemetadata'}, 'hello world', 'customer metadata';
        }

        Create_with_a_token: {
            my $token = $stripe->post_token(card => $fake_card);
            my $customer = $stripe->post_customer(
                card => $token->id,
            );
            isa_ok $customer, 'Net::Stripe::Customer', 'got back a customer';
            ok $customer->id, 'customer has an id';
            my $path = 'customers/'.$customer->id.'/cards/'.$customer->default_card;
            my $card = $stripe->_get( $path );
            is $card->last4, '4242', 'card token ok';
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
            is $subs->plan->id, $freeplan->id;

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
            is $priceysubs->plan->id, $priceyplan->id;
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
        my $token = $stripe->post_token(card => $fake_card);
        ok $token->id, 'token has an id';
        my $customer = $stripe->post_customer(
            card => $token,
            plan => $plan->id,
        );
        ok $customer->id, 'customer has an id';
        is $customer->subscription->plan->id, $plan->id, 'customer has a plan';
        my $path = 'customers/'.$customer->id.'/cards/'.$customer->default_card;
        my $card = $stripe->_get( $path );
        is $card->last4, $token->card->last4, 'customer has a card';
        
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

        # swallow the expected warning rather than have it print out durring tests.
        close STDERR;
        open(STDERR, ">", "/dev/null");
        eval { $stripe->get_invoiceitem(invoice_item => $item->id) };
        like $@, qr/No such invoiceitem/, 'correct error message';
        close STDERR;
        open(STDERR, ">&", STDOUT);
    }
}

done_testing();
