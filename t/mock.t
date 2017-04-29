#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Test::Exception;
use Net::Stripe;
use DateTime;
use DateTime::Duration;
use JSON;
use Test::LWP::UserAgent;

my $API_KEY = $ENV{STRIPE_API_KEY};
if ($API_KEY) {
    plan skip_all => "STRIPE_API_KEY env var is defined.";
    exit
}


{   package My::UA;

    sub new {
        bless { UA => 'Test::LWP::UserAgent'->new }, shift
    }


    sub state {
        my ($self, $key, $value) = @_;
        if (3 == @_) {
            $self->{STATE}{$key} = $value;
        }
        return ($self->{STATE}{$key})
    }


    sub AUTOLOAD {
        ( my $method = our $AUTOLOAD ) =~ s/.*:://;
        my $self = shift;
        return $self->{UA}->$method(@_)
    }

}


$API_KEY = 'MOCK';

my $future = DateTime->now + DateTime::Duration->new(years => 1);
my $future_ymdhms = $future->ymd('-') . '-' . $future->hms('-');

my $fake_card = {
    number    => '4242-4242-4242-4242',
    exp_month => $future->month,
    exp_year  => $future->year,
    cvc       => 123,
    name      => 'Anonymous',
    object    => 'card',
    country   => 'US',
    last4     => '4242',
    brand     => 'Visa',
    cvc_check => 'pass',
};

my $fcj = to_json($fake_card);

my $myua = 'My::UA'->new;
my $stripe = Net::Stripe->new( api_key       => $API_KEY,
                               debug         => 1,
                               debug_network => 0,
                               ua            => $myua,
                             );


sub _list {
    my $member = shift;
    qq%{"object": "list", "url": "/v1/plans", "has_more": false, "data": [ $member ]}%
}


# Examples from the API documentation
my $token = '{
      "id": "tok_17ELBv2eZvKYlo2CNk0Zk5an",
      "object": "token",
      "card": {
        "id": "card_17ELBv2eZvKYlo2CbWp7aIOS",
        "object": "card",
        "address_city": null,
        "address_country": null,
        "address_line1": null,
        "address_line1_check": null,
        "address_line2": null,
        "address_state": null,
        "address_zip": null,
        "address_zip_check": null,
        "brand": "Visa",
        "country": "US",
        "cvc_check": null,
        "dynamic_last4": null,
        "exp_month": 8,
        "exp_year": 2016,
        "funding": "credit",
        "last4": "4242",
        "metadata": {
        },
        "name": null,
        "tokenization_method": null
      },
      "client_ip": null,
      "created": 1449241787,
      "livemode": false,
      "type": "card",
      "used": false
}';

my $plan = qq/{
      "id": "$future_ymdhms",
      "object": "plan",
      "amount": 50,
      "created": 1395968059,
      "currency": "usd",
      "interval": "month",
      "interval_count": 1,
      "livemode": false,
      "metadata": {
      },
      "name": "Basic Plan",
      "statement_descriptor": null,
      "trial_period_days": null
    }/;

my $coupon = qq/{
  "id": "coupon-$future_ymdhms",
  "object": "coupon",
  "amount_off": null,
  "created": 1449265763,
  "currency": "usd",
  "duration": "once",
  "duration_in_months": null,
  "livemode": false,
  "max_redemptions": null,
  "metadata": {
  },
  "percent_off": 25,
  "redeem_by": null,
  "times_redeemed": 0,
  "valid": true
}/;


my @r200 = (200, 'OK', ['Content-Type' => 'text/json']);
sub r200 { 'HTTP::Response'->new(@r200, @_) }

my $ok = sub {
    my ($regex, $data) = @_;
    $myua->map_response(qr/$regex/, r200($data));
};

my $deleted = sub {
    my $regex = shift;
    $myua->map_response(qr/$regex/,
                        'HTTP::Response'->new(500, 'Deleted', []));
};

$ok->('v1/tokens', $token);
$ok->('v1/plans\?limit=1', _list($plan));

$myua->map_response(sub { my $r = shift;
                          if ($r->url =~ m{v1/plans}
                              && 'DELETE' eq $r->method) {
                              $myua->state(plan => 1);
                              return 1
                          }
                          return 0
                      },
                    r200(to_json({ deleted => 1 })));

$myua->map_response(sub { my $r = shift;
                          if ($r->url =~ m{v1/plans}
                              && $r->content =~ /id=free/
                             ){
                              $myua->state(plan => 0);
                              return 1
                          }
                          return 0
                      },
                    r200($plan));



$myua->map_response(qr{v1/plans},
            sub { 'HTTP::Response'->new(
                      $myua->state('plan') ? (500, 'Deleted')
                                           : (@r200, $plan))});

$ok->('v1/coupons\?', _list($coupon));

$myua->map_response(sub { my $r = shift;
                          if ($r->url =~ m{v1/coupons}
                              && 'DELETE' eq $r->method) {
                              $myua->state(coupon => 1);
                              return 1
                            }
                          return 0
                      },
                    r200(to_json({ deleted => 1 })));

$myua->map_response(qr{v1/coupons},
                    sub { 'HTTP::Response'->new(
                              $myua->state('coupon') ? (500, 'Deleted')
                                                     : (@r200, $coupon))});

# ---------------------------------------------------------------------------

isa_ok $stripe, 'Net::Stripe', 'API object created today';

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

done_testing();
