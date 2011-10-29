#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Test::Exception;
use Net::Stripe;
use DateTime;
use DateTime::Duration;
use Try::Tiny;

my $API_KEY = $ENV{STRIPE_API_KEY};
unless ($API_KEY) {
    plan skip_all => "No STRIPE_API_KEY env var is defined.";
    exit;
}

my $future = DateTime->now + DateTime::Duration->new(years => 1);
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
        try {
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
        }
        catch {
            my $e = $_;
            isa_ok $e, 'Net::Stripe::Error', 'error raised is an object';
            is $e->type, 'invalid_request_error', 'error type';
            is $e->message, 'Invalid currency: zzz', 'error message';
            is $e->param, 'currency', 'error param';
        }
    }
}

# To Test:
# For posting a charge:
# * fetching charges just for one customer
# * fetching charges with an offset

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

        # TODO: create with a coupon, create with a plan
        # Posting a customer with a card
        # Posting a customer with a coupon
        # trial_end
    }
}

done_testing();


__DATA__

    /v1/customers/{CUSTOMER_ID}/subscription
    /v1/invoices
    /v1/invoices/{INVOICE_ID}
    /v1/invoiceitems
    /v1/invoiceitems/{INVOICEITEM_ID}
    /v1/tokens
    /v1/tokens/{TOKEN_ID}

