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

Charges: {
    my $stripe = Net::Stripe->new(api_key => $API_KEY);
    Sunny_day: {
        my $charge;
        lives_ok { 
            $charge = $stripe->post_charge(
                amount => 3300,
                currency => 'usd',
                card => {
                    number => '4242-4242-4242-4242',
                    exp_month => $future->month,
                    exp_year  => $future->year,
                    cvc => 123,
                    name => 'Anonymous',
                },
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
        is $card->country, 'US';
        is $card->cvc_check, 'pass';
        is $card->exp_month, $future->month;
        is $card->exp_year,  $future->year;
        is $card->last4, '4242';
        is $card->type, 'Visa';

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

    Rainy_day: {
        throws_ok {
            $stripe->post_charge(
                amount => 3300,
                currency => 'usd',
                description => 'Wikileaks donation',
            );
        } qr/customer OR card is required/, 'missing card and customer';

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
        } qr/customer OR card is required/, 'missing card and customer';

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


done_testing();


__DATA__

    /v1/customers
    /v1/customers/{CUSTOMER_ID}
    /v1/customers/{CUSTOMER_ID}/subscription
    /v1/invoices
    /v1/invoices/{INVOICE_ID}
    /v1/invoiceitems
    /v1/invoiceitems/{INVOICEITEM_ID}
    /v1/tokens
    /v1/tokens/{TOKEN_ID}

