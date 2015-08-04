package Net::Stripe;

use Moose;
use Kavorka;
use LWP::UserAgent;
use HTTP::Request::Common qw/GET POST DELETE/;
use MIME::Base64 qw/encode_base64/;
use URI::Escape qw/uri_escape/;
use JSON qw/decode_json/;
use Net::Stripe::Token;
use Net::Stripe::Invoiceitem;
use Net::Stripe::Invoice;
use Net::Stripe::Card;
use Net::Stripe::Plan;
use Net::Stripe::Coupon;
use Net::Stripe::Charge;
use Net::Stripe::Customer;
use Net::Stripe::Discount;
use Net::Stripe::Subscription;
use Net::Stripe::Error;
use Net::Stripe::BalanceTransaction;
use Net::Stripe::List;
use Net::Stripe::LineItem;
use Net::Stripe::Refund;

# ABSTRACT: API client for Stripe.com

=head1 SYNOPSIS

 my $stripe     = Net::Stripe->new(api_key => $API_KEY);
 my $card_token = 'a token';
 my $charge = $stripe->post_charge(  # Net::Stripe::Charge
     amount      => 12500,
     currency    => 'usd',
     card        => $card_token,
     description => 'YAPC Registration',
 );
 print "Charge was not paid!\n" unless $charge->paid;
 my $card = $charge->card;           # Net::Stripe::Card

 # look up a charge by id
 my $same_charge = $stripe->get_charge(charge_id => $charge->id);

 # ... and the api mirrors https://stripe.com/docs/api
 # Charges: post_charge() get_charge() refund_charge() get_charges()
 # Customer: post_customer()

=head1 DESCRIPTION

This module is a wrapper around the Stripe.com HTTP API.  Methods are
generally named after the HTTP method and the object name.

This method returns Moose objects for responses from the API.

=method new PARAMHASH

This creates a new stripe api object.  The following parameters are accepted:

=over

=item api_key

This is required. You get this from your Stripe Account settings.

=item debug

You can set this to true to see extra debug info.

=item debug_network

You can set this to true to see the actual network requests.

=back

=cut

has 'debug'         => (is => 'rw', isa => 'Bool',   default    => 0, documentation => "The debug flag");
has 'debug_network' => (is => 'rw', isa => 'Bool',   default    => 0, documentation => "The debug network request flag");
has 'api_key'       => (is => 'ro', isa => 'Str',    required   => 1, documentation => "You get this from your Stripe Account settings");
has 'api_base'      => (is => 'ro', isa => 'Str',    lazy_build => 1, documentation => "This is the base part of the URL for every request made");
has 'ua'            => (is => 'ro', isa => 'Object', lazy_build => 1, documentation => "The LWP::UserAgent that is used for requests");

=charge_method post_charge

Create a new charge

L<https://stripe.com/docs/api#create_charge>

=over

=item * amount - Int - amount to charge

=item * currency - Str - currency for charge

=item * customer - L<Net::Stripe::Customer>, HashRef or Str - customer to charge - optional

=item * card - L<Net::Stripe::Card>, L<Net::Stripe::Token>, Str or HashRef - card to use - optional

=item * description - Str - description for the charge - optional

=item * metadata - HashRef - metadata for the charge - optional

=item * capture - Bool - optional

=item * statement_description - Str - description for statement - optional

=item * application_fee - Int - optional

=back

Returns L<Net::Stripe::Charge>

  $stripe->post_charge(currency => 'USD', amount => 500, customer => 'testcustomer');

=charge_method get_charge

Retrieve a charge.

L<https://stripe.com/docs/api#retrieve_charge>

=over

=item * charge_id - Str - charge id to retrieve

=back

Returns L<Net::Stripe::Charge>

  $stripe->get_charge(charge_id => 'chargeid');

=charge_method refund_charge

Refunds a charge

L<https://stripe.com/docs/api#refund_charge>

=over

=item * charge - L<Net::Stripe::Charge> or Str - charge or charge_id to refund

=item * amount - Int - amount to refund in cents, optional

=back

Returns a new L<Net::Stripe::Refund>.

  $stripe->refund_charge(charge => $charge, amount => 500);

=charge_method get_charges

Returns a L<Net::Stripe::List> object containing L<Net::Stripe::Charge> objects.

L<https://stripe.com/docs/api#list_charges>

=over

=item * created - HashRef - created conditions to match, optional

=item * customer - L<Net::Stripe::Customer> or Str - customer to match

=item * ending_before - Str - ending before condition, optional

=item * limit - Int - maximum number of charges to return, optional

=item * starting_after - Str - starting after condition, optional

=back

Returns a list of L<Net::Stripe::Charge> objects.

  $stripe->get_charges(customer => $customer, limit => 5);

=cut

Charges: {
    method post_charge(Int :$amount,
                       Str :$currency,
                       Net::Stripe::Customer|HashRef|Str :$customer?,
                       Net::Stripe::Card|Net::Stripe::Token|Str|HashRef :$card?,
                       Str :$description?,
                       HashRef :$metadata?,
                       Bool :$capture?,
                       Str :$statement_description?,
                       Int :$application_fee?
                     ) {
        my $charge = Net::Stripe::Charge->new(amount => $amount,
                                              currency => $currency,
                                              customer => $customer,
                                              card => $card,
                                              description => $description,
                                              metadata => $metadata,
                                              capture => $capture,
                                              statement_description => $statement_description,
                                              application_fee => $application_fee
                                          );
        return $self->_post('charges', $charge);
    }

    method get_charge(Str :$charge_id) {
        return $self->_get("charges/" . $charge_id);
    }

    method refund_charge(Net::Stripe::Charge|Str :$charge, Int :$amount?) {
        if (ref($charge)) {
            $charge = $charge->id;
        }

        my $refund = Net::Stripe::Refund->new(id => $charge,
                                              amount => $amount
                                          );
        return $self->_post("charges/$charge/refunds", $refund);
    }

    method get_charges(HashRef :$created?,
                       Net::Stripe::Customer|Str :$customer?,
                       Str :$ending_before?,
                       Int :$limit?,
                       Str :$starting_after?) {
        if (ref($customer)) {
            $customer = $customer->id;
        }
        $self->_get_collections('charges',
                                created => $created,
                                customer => $customer,
                                ending_before => $ending_before,
                                limit => $limit,
                                starting_after => $starting_after
                            );
    }

}

=balance_transaction_method get_balance_transaction

Retrieve a balance transaction

L<https://stripe.com/docs/api#retrieve_balance_transaction>

=over

=item * id - Str - balance transaction ID to retrieve.

=back

Returns a L<Net::Stripe::BalanceTransaction>

  $stripe->get_balance_transaction(id => 'id');

=cut


BalanceTransactions: {
    method get_balance_transaction(Str :$id) {
        return $self->_get("balance/history/$id");
    }
}


=customer_method post_customer

Create or update a customer.

L<https://stripe.com/docs/api#create_customer>

=over

=item * customer - L<Net::Stripe::Customer> - existing customer to update, optional

=item * account_balance - Int, optional

=item * card - L<Net::Stripe::Card>, L<Net::Stripe::Token>, Str or HashRef, default card for the customer, optional

=item * coupon - Str, optional

=item * description - Str, optional

=item * email - Str, optional

=item * metadata - HashRef, optional

=item * plan - Str, optional

=item * quantity - Int, optional

=item * trial_end - Int or Str, optional

=back

Returns a L<Net::Stripe::Customer> object

  my $customer = $stripe->post_customer(
    card => $fake_card,
    email => 'stripe@example.com',
    description => 'Test for Net::Stripe',
  );

=customer_method list_subscriptions

Returns the subscriptions for a customer

L<https://stripe.com/docs/api#list_subscriptions>

=over

=item * customer - L<Net::Stripe::Customer> or Str

=item * ending_before - Str, optional

=item * limit - Int, optional

=item * starting_after - Str, optional

=back

Returns a list of L<Net::Stripe::Subscription> objects

=customer_method get_customer

Retrieve a customer

L<https://stripe.com/docs/api#retrieve_customer>

=over

=item * customer_id - Str - the customer id to retrieve

=back

Returns a L<Net::Stripe::List> object containing L<Net::Stripe::Customer> objects.

  $stripe->get_customer(customer_id => $id);

=customer_method delete_customer

Delete a customer

L<https://stripe.com/docs/api#delete_customer>

=over

=item * customer - L<Net::Stripe::Customer> or Str - the customer to delete

=back

Returns a L<Net::Stripe::Customer> object

  $stripe->delete_customer(customer => $customer);

=customer_method get_customers

Returns a list of customers.

L<https://stripe.com/docs/api#list_customers>

=over

=item * created - HashRef - created conditions, optional

=item * ending_before - Str, optional

=item * limit - Int, optional

=item * starting_after - Str, optional

=back

Returns a L<Net::Stripe::List> object containing L<Net::Stripe::Customer> objects.

  $stripe->get_customers(limit => 7);

=cut

Customers: {
    method post_customer(Net::Stripe::Customer|Str :$customer?,
                         Int :$account_balance?,
                         Net::Stripe::Card|Net::Stripe::Token|Str|HashRef :$card?,
                         Str :$coupon?,
                         Str :$default_card?,
                         Str :$description?,
                         Str :$email?,
                         HashRef :$metadata?,
                         Str :$plan?,
                         Int :$quantity?,
                         Int|Str :$trial_end?) {

        if (defined($card) && ref($card) eq 'HASH') {
            $card = Net::Stripe::Card->new($card);
        }

        if (ref($customer) eq 'Net::Stripe::Customer') {
            return $self->_post("customers/" . $customer->id, $customer);
        } elsif (defined($customer)) {
            my %args = (
                account_balance => $account_balance,
                card => $card,
                coupon => $coupon,
                default_card => $default_card,
                email => $email,
                metadata => $metadata,
            );

            return $self->_post("customers/" . $customer, _defined_arguments(\%args));
        }


        $customer = Net::Stripe::Customer->new(account_balance => $account_balance,
                                               card => $card,
                                               coupon => $coupon,
                                               description => $description,
                                               email => $email,
                                               metadata => $metadata,
                                               plan => $plan,
                                               quantity => $quantity,
                                               trial_end => $trial_end);
        return $self->_post('customers', $customer);
    }

    method list_subscriptions(Net::Stripe::Customer|Str :$customer,
                              Str :$ending_before?,
                              Int :$limit?,
                              Str :$starting_after?) {
        if (ref($customer)) {
            $customer = $customer->id;
        }
        return $self->_get_collections("customers/$customer/subscriptions",
                           ending_before => $ending_before,
                           limit => $limit,
                           starting_after => $starting_after
                       );
    }

    method get_customer(Str :$customer_id) {
        return $self->_get("customers/$customer_id");
    }

    method delete_customer(Net::Stripe::Customer|Str :$customer) {
        if (ref($customer)) {
            $customer = $customer->id;
        }
        $self->_delete("customers/$customer");
    }

    method get_customers(HashRef :$created?, Str :$ending_before?, Int :$limit?, Str :$starting_after?) {
        $self->_get_collections('customers',
                                created => $created,
                                ending_before => $ending_before,
                                limit => $limit,
                                starting_after => $starting_after
                            );
    }
}

=card_method get_card

Retrieve information about a customer's card.

L<https://stripe.com/docs/api#retrieve_card>

=over

=item * customer - L<Net::Stripe::Customer> or Str - the customer

=item * card_id - Str - the card ID to retrieve

=back

Returns a L<Net::Stripe::Card>

  $stripe->get_card(customer => 'customer_id', card_id => 'abcdef');

=card_method post_card

Create or update a card

L<https://stripe.com/docs/api#create_card>

=over

=item * customer - L<Net::Stripe::Customer> or Str

=item * card - L<Net::Stripe::Card> or HashRef

=back

Returns a L<Net::Stripe::Card>

  $stripe->create_card(customer => $customer, card => $card);

=card_method get_cards

Returns a list of cards

L<https://stripe.com/docs/api#list_cards>

=over

=item * customer - L<Net::Stripe::Customer> or Str

=item * ending_before - Str, optional

=item * limit - Int, optional

=item * starting_after - Str, optional

=back

Returns a L<Net::Stripe::List> object containing L<Net::Stripe::Card> objects.

  $stripe->list_cards(customer => 'abcdec', limit => 10);

=card_method delete_card

Delete a card.

L<https://stripe.com/docs/api#delete_card>

=over

=item * customer - L<Net::Stripe::Customer> or Str

=item * card - L<Net::Stripe::Card> or Str

=back

Returns a L<Net::Stripe::Card>.

  $stripe->delete_card(customer => $customer, card => $card);

=cut

Cards: {
    method get_card(Net::Stripe::Customer|Str :$customer,
                    Str :$card_id) {
        if (ref($customer)) {
            $customer = $customer->id;
        }
        return $self->_get("customers/$customer/cards/$card_id");
    }

    method get_cards(Net::Stripe::Customer|Str $customer,
                     HashRef :$created?,
                     Str :$ending_before?,
                     Int :$limit?,
                     Str :$starting_after?) {
        if (ref($customer)) {
            $customer = $customer->id;
        }

        $self->_get_collections('cards',
                                id => $customer,
                                created => $created,
                                ending_before => $ending_before,
                                limit => $limit,
                                starting_after => $starting_after);
    }

    method post_card(Net::Stripe::Customer|Str :$customer,
                     HashRef|Net::Stripe::Card :$card) {
        if (ref($customer)) {
            $customer = $customer->id;
        }
        # Update the card.
        if (ref($card) eq 'Net::Stripe::Card' && $card->id) {
            return $self->_post("customers/$customer/cards", $card);
        }
        if (ref($card) eq 'HASH') {
            $card = Net::Stripe::Card->new($card);
        }
        if (defined($card->id)) {
            return $self->_post("customers/$customer/cards/" . $card->id, $card);
        }
        return $self->_post("customers/$customer/cards", $card);
    }

    method delete_card(Net::Stripe::Customer|Str :$customer, Net::Stripe::Card|Str :$card) {
      if (ref($customer)) {
          $customer = $customer->id;
      }

      if (ref($card)) {
          $card = $card->id;
      }

      return $self->_delete("customers/$customer/cards/$card");
    }
}

=subscription_method post_subscription

Adds or updates a subscription for a customer.

L<https://stripe.com/docs/api#create_subscription>

=over

=item * customer - L<Net::Stripe::Customer>

=item * subscription - L<Net::Stripe::Subscription> or Str

=item * card - L<Net::Stripe::Card>, L<Net::Stripe::Token>, Str or HashRef, default card for the customer, optional

=item * coupon - Str, optional

=item * description - Str, optional

=item * plan - Str, optional

=item * quantity - Int, optional

=item * trial_end - Int, or Str optional

=item * application_fee_percent - Int, optional

=item * prorate - Bool, optional

=back

Returns a L<Net::Stripe::Customer> object

  $stripe->post_subscription(customer => $customer, plan => 'testplan');

=subscription_method get_subscription

Returns a customers subscription

=over

=item * customer - L<Net::Stripe::Customer> or Str

=back

Returns a L<Net::Stripe::Subscription>

  $stripe->get_subscription(customer => 'test123');

=subscription_method delete_subscription

Cancel a customer's subscription

L<https://stripe.com/docs/api#cancel_subscription>

=over

=item * customer - L<Net::Stripe::Customer> or Str

=item * subscription - L<Net::Stripe::Subscription> or Str

=item * at_period_end - Bool, optional

=back

Returns a L<Net::Stripe::Subscription> object.

  $stripe->delete_subscription(customer => $customer, subscription => $subscription);

=cut

Subscriptions: {
    method get_subscription(Net::Stripe::Customer|Str :$customer) {
        if (ref($customer)) {
           $customer = $customer->id;
        }
        return $self->_get("customers/$customer/subscription");
    }

    # adds a subscription, keeping any existing subscriptions unmodified
    method post_subscription(Net::Stripe::Customer|Str :$customer,
                             Net::Stripe::Subscription|Str :$subscription?,
                             Net::Stripe::Plan|Str :$plan?,
                             Str :$coupon?,
                             Int|Str :$trial_end?,
                             Net::Stripe::Card|Net::Stripe::Token|Str|HashRef :$card?,
                             Int :$quantity? where { $_ >= 0 },
                             Num :$application_fee_percent?,
                             Bool :$prorate? = 1
                         ) {
        if (ref($customer)) {
            $customer = $customer->id;
        }

        if (ref($plan)) {
            $plan = $plan->id;
        }

        my %args = (plan => $plan,
                    coupon => $coupon,
                    trial_end => $trial_end,
                    card => $card,
                    prorate => $prorate ? 'true' : 'false',
                    quantity => $quantity,
                    application_fee_percent => $application_fee_percent);

        if (ref($subscription) && $subscription eq 'Net::Stripe::Subscription') {
            return $self->_post("customers/$customer/subscriptions/" . $subscription->id, $subscription);
        } elsif (defined($subscription) && !ref($subscription)) {
            return $self->_post("customers/$customer/subscriptions/" . $subscription, _defined_arguments(\%args));
        }

        return $self->_post("customers/$customer/subscriptions", _defined_arguments(\%args));
    }

    method delete_subscription(Net::Stripe::Customer|Str :$customer,
                               Net::Stripe::Subscription|Str :$subscription,
                               Bool :$at_period_end?
                           ) {
        if (ref($customer)) {
            $customer = $customer->id;
        }
        if (ref($subscription)) {
            $subscription = $subscription->id;
        }

        my $query = '';
        $query .= '?at_period_end=true' if $at_period_end;
        return $self->_delete("customers/$customer/subscriptions/$subscription$query");
    }
}

=token_method post_token

Create a new token

L<https://stripe.com/docs/api#create_card_token>

=over

=item card - L<Net::Stripe::Card> or HashRef

=back

Returns a L<Net::Stripe::Token>

  $stripe->post_token(card => $test_card);

=token_method get_token

Retreives an existing token.

L<https://stripe.com/docs/api#retrieve_token>

=over

=item * token_id - Str

=back

Returns a L<Net::Stripe::Token>

  $stripe->get_token(token_id => 'testtokenid');

=cut

Tokens: {
    method post_token(Net::Stripe::Card|HashRef :$card) {
        my $token = Net::Stripe::Token->new(card => $card);
        return $self->_post('tokens', $token);
    }

    method get_token(Str :$token_id) {
        return $self->_get("tokens/$token_id");
    }
}

=plan_method post_plan

Create a new plan

L<https://stripe.com/docs/api#create_plan>

=over

=item * id - Str - identifier of the plan

=item * amount - Int - cost of the plan in cents

=item * currency - Str

=item * interval - Str

=item * interval_count - Int - optional

=item * name - Str - name of the plan

=item * trial_period_days - Int - optional

=item * statement_description - Str - optional

=back

Returns a L<Net::Stripe::Plan> object

  $stripe->post_plan(
     id => "free-$future_ymdhms",
     amount => 0,
     currency => 'usd',
     interval => 'year',
     name => "Freeplan $future_ymdhms",
  );

=plan_method get_plan

Retrieves a plan.

=over

=item * plan_id - Str

=back

Returns a L<Net::Stripe::Plan>

  $stripe->get_plan(plan_id => 'plan123');

=plan_method delete_plan

Delete a plan.

L<https://stripe.com/docs/api#delete_plan>

=over

=item * plan_id - L<Net::Stripe::Plan> or Str

=back

Returns a L<Net::Stripe::Plan> object

  $stripe->delete_plan(plan_id => $plan);

=plan_method get_plans

Return a list of Plans

L<https://stripe.com/docs/api#list_plans>

=over

=item * ending_before - Str, optional

=item * limit - Int, optional

=item * starting_after - Str, optional

=back

Returns a L<Net::Stripe::List> object containing L<Net::Stripe::Plan> objects.

  $stripe->get_plans(limit => 10);

=cut

Plans: {
    method post_plan(Str :$id,
                     Int :$amount,
                     Str :$currency,
                     Str :$interval,
                     Int :$interval_count?,
                     Str :$name,
                     Int :$trial_period_days?,
                     HashRef :$metadata?,
                     Str :$statement_description?) {
        my $plan = Net::Stripe::Plan->new(id => $id,
                                          amount => $amount,
                                          currency => $currency,
                                          interval => $interval,
                                          interval_count => $interval_count,
                                          name => $name,
                                          trial_period_days => $trial_period_days,
                                          metadata => $metadata,
                                          statement_description => $statement_description);
        return $self->_post('plans', $plan);
    }

    method get_plan(Str :$plan_id) {
        return $self->_get("plans/" . uri_escape($plan_id));
    }

    method delete_plan(Str|Net::Stripe::Plan $plan) {
        if (ref($plan)) {
            $plan = $plan->id;
        }
        $self->_delete("plans/$plan");
    }

    method get_plans(Str :$ending_before?, Int :$limit?, Str :$starting_after?) {
        $self->_get_collections('plans',
                                ending_before => $ending_before,
                                limit => $limit,
                                starting_after => $starting_after);
    }
}


=coupon_method post_coupon

Create or update a coupon

L<https://stripe.com/docs/api#create_coupon>

=over

=item * id - Str, optional

=item * duration - Str

=item * amount_offset - Int, optional

=item * currency - Str, optional

=item * duration_in_months - Int, optional

=item * max_redemptions - Int, optional

=item * metadata - HashRef, optional

=item * percent_off - Int, optional

=item * redeem_by - Int, optional

=back

Returns a L<Net::Stripe::Coupon> object.

  $stripe->post_coupon(
     id => $coupon_id,
     percent_off => 100,
     duration => 'once',
     max_redemptions => 1,
     redeem_by => time() + 100,
  );

=coupon_method get_coupon

Retreive a coupon

L<https://stripe.com/docs/api#retrieve_coupon>

=over

=item * coupon_id - Str

=back

Returns a L<Net::Stripe::Coupon> object.

  $stripe->get_coupon(coupon_id => 'id');

=coupon_method delete_coupon

Delete a coupon

L<https://stripe.com/docs/api#delete_coupon>

=over

=item * coupon_id - Str

=back

Returns a L<Net::Stripe::Coupon>

  $stripe->delete_coupon(coupon_id => 'coupon123');

=coupon_method get_coupons

=over

=item * ending_before - Str, optional

=item * limit - Int, optional

=item * starting_after - Str, optional

=back

Returns a L<Net::Stripe::List> object containing L<Net::Stripe::Coupon> objects.

  $stripe->get_coupons(limit => 15);

=cut

Coupons: {
    method post_coupon(Str :$id?,
                       Str :$duration,
                       Int :$amount_off?,
                       Str :$currency?,
                       Int :$duration_in_months?,
                       Int :$max_redemptions?,
                       HashRef :$metadata?,
                       Int :$percent_off?,
                       Int :$redeem_by?) {
        my $coupon = Net::Stripe::Coupon->new(id => $id,
                                              duration => $duration,
                                              amount_off => $amount_off,
                                              currency => $currency,
                                              duration_in_months => $duration_in_months,
                                              max_redemptions => $max_redemptions,
                                              metadata => $metadata,
                                              percent_off => $percent_off,
                                              redeem_by => $redeem_by
                                          );
        return $self->_post('coupons', $coupon);
    }

    method get_coupon(Str :$coupon_id) {
        return $self->_get("coupons/" . uri_escape($coupon_id));
    }

    method delete_coupon($id) {
        $id = $id->id if ref($id);
        $self->_delete("coupons/$id");
    }

    method get_coupons(Str :$ending_before?, Int :$limit?, Str :$starting_after?) {
        $self->_get_collections('coupons',
                                ending_before => $ending_before,
                                limit => $limit,
                                starting_after => $starting_after);
    }
}

=discount_method delete_customer_discount

Deleting a Customer-wide Discount

L<https://stripe.com/docs/api/curl#delete_discount>

=over

=item * customer - L<Net::Stripe::Customer> or Str - the customer with a discount to delete

=back

  $stripe->delete_customer_discount(customer => $customer);

returns hashref of the form

  {
    deleted => <bool>
  }


=cut

Discounts: {
    method delete_customer_discount(Net::Stripe::Customer|Str :$customer) {
        if (ref($customer)) {
            $customer = $customer->id;
        }
        $self->_delete("customers/$customer/discount");
    }
}


=invoice_method post_invoice

Update an invoice

=over

=item * invoice - L<Net::Stripe::Invoice>, Str

=item * application_fee - Int - optional

=item * closed - Bool - optional

=item * description - Str - optional

=item * metadata - HashRef - optional

=back

Returns a L<Net::Stripe::Invoice>

  $stripe->post_invoice(invoice => $invoice, closed => 'true')

=invoice_method get_invoice

=over

=item * invoice_id - Str

=back

Returns a L<Net::Stripe::Invoice>

  $stripe->get_invoice(invoice_id => 'testinvoice');

=invoice_method pay_invoice

=over

=item * invoice_id - Str

=back

Returns a L<Net::Stripe::Invoice>

  $stripe->pay_invoice(invoice_id => 'testinvoice');

=invoice_method get_invoices

Returns a list of invoices

L<https://stripe.com/docs/api#list_customer_invoices>

=over

=item * customer - L<Net::Stripe::Customer> or Str, optional

=item * date - Int or HashRef, optional

=item * ending_before - Str, optional

=item * limit - Int, optional

=item * starting_after - Str, optional

=back

Returns a L<Net::Stripe::List> object containing L<Net::Stripe::Invoice> objects.

  $stripe->get_invoices(limit => 10);

=invoice_method create_invoice

Create a new invoice

L<https://stripe.com/docs/api#create_invoice>

=over

=item * customer - L<Net::Stripe::Customer>, Str

=item * application_fee - Int - optional

=item * description - Str - optional

=item * metadata - HashRef - optional

=item * subscription - L<Net::Stripe::Subscription> or Str, optional

=back

Returns a L<Net::Stripe::Invoice>

  $stripe->create_invoice(customer => 'custid', description => 'test');

=invoice_method get_invoice

=over

=item * invoice_id - Str

=back

Returns a L<Net::Stripe::Invoice>

  $stripe->get_invoice(invoice_id => 'test');

=invoice_method get_upcominginvoice

=over

=item * customer, L<Net::Stripe::Cusotmer> or Str

=back

Returns a L<Net::Stripe::Invoice>

  $stripe->get_upcominginvoice(customer => $customer);

=cut

Invoices: {

    method create_invoice(Net::Stripe::Customer|Str :$customer,
                          Int :$application_fee?,
                          Str :$description?,
                          HashRef :$metadata?,
                          Net::Stripe::Subscription|Str :$subscription?) {
        if (ref($customer)) {
            $customer = $customer->id;
        }

        if (ref($subscription)) {
            $subscription = $subscription->id;
        }

        return $self->_post("invoices",
                            {
                                customer => $customer,
                                application_fee => $application_fee,
                                description => $description,
                                metadata => $metadata,
                                subscription =>$subscription
                            });
    }


    method post_invoice(Net::Stripe::Invoice|Str :$invoice,
                        Int :$application_fee?,
                        Bool :$closed?,
                        Str :$description?,
                        HashRef :$metadata?) {
        if (ref($invoice)) {
            $invoice = $invoice->id;
        }

        return $self->_post("invoices/$invoice",
                            {
                                application_fee => $application_fee,
                                closed => $closed,
                                description => $description,
                                metadata => $metadata
                            });
    }

    method get_invoice(Str :$invoice_id) {
        return $self->_get("invoices/$invoice_id");
    }

    method pay_invoice(Str :$invoice_id) {
        return $self->_post("invoices/$invoice_id/pay");
    }

    method get_invoices(Net::Stripe::Customer|Str :$customer?,
                        Int|HashRef :$date?,
                        Str :$ending_before?,
                        Int :$limit?,
                        Str :$starting_after?) {
        if (ref($customer)) {
            $customer = $customer->id
        }

        $self->_get_collections('invoices', customer => $customer,
                            date => $date,
                            ending_before => $ending_before,
                            limit => $limit,
                            starting_after => $starting_after);
    }

    method get_upcominginvoice(Net::Stripe::Customer|Str $customer) {
        if (ref($customer)) {
            $customer = $customer->id;
        }
        return $self->_get("invoices/upcoming?customer=$customer");
    }
}

=invoiceitem_method create_invoiceitem

Create an invoice item.

L<https://stripe.com/docs/api#create_invoiceitem>

=over

=item * customer - L<Net::Stripe::Customer> or Str

=item * amount - Int

=item * currency - Str

=item * invoice - L<Net::Stripe::Invoice> or Str, optional

=item * subscription - L<Net::Stripe::Subscription> or Str, optional

=item * description - Str, optional

=item * metadata - HashRef, optional

=back

Returns a L<Net::Stripe::Invoiceitem> object

  $stripe->create_invoiceitem(customer => 'test', amount => 500, currency => 'USD');

=invoiceitem_method post_invoiceitem

Update an invoice item.

L<https://stripe.com/docs/api#create_invoiceitem>

=over

=item * invoice_item - L<Net::Stripe::Invoiceitem> or Str

=item * amount - Int, optional

=item * description - Str, optional

=item * metadata - HashRef, optional

=back

Returns a L<Net::Stripe::Invoiceitem>

  $stripe->post_invoiceitem(invoice_item => 'itemid', amount => 750);

=invoiceitem_method get_invoiceitem

Retrieve an invoice item.

=over

=item * invoice_item - Str

=back

Returns a L<Net::Stripe::Invoiceitem>

  $stripe->get_invoiceitem(invoice_item => 'testitemid');

=invoiceitem_method delete_invoiceitem

Delete an invoice item

=over

=item * invoice_item - L<Net::Stripe::Invoiceitem> or Str

=back

Returns a L<Net::Stripe::Invoiceitem>

  $stripe->delete_invoiceitem(invoice_item => $invoice_item);

=invoiceitem_method get_invoiceitems

=over

=item * customer - L<Net::Stripe::Customer> or Str, optional

=item * date - Int or HashRef, optional

=item * ending_before - Str, optional

=item * limit - Int, optional

=item * starting_after - Str, optional

=back

Returns a L<Net::Stripe::List> object containing L<Net::Stripe::Invoiceitem> objects.

  $stripe->get_invoiceitems(customer => 'test', limit => 30);

=cut

InvoiceItems: {
    method create_invoiceitem(Net::Stripe::Customer|Str :$customer,
                              Int :$amount,
                              Str :$currency,
                              Net::Stripe::Invoice|Str :$invoice?,
                              Net::Stripe::Subscription|Str :$subscription?,
                              Str :$description?,
                              HashRef :$metadata?) {
        if (ref($customer)) {
            $customer = $customer->id;
        }

        if (ref($invoice)) {
            $invoice = $invoice->id;
        }

        if (ref($subscription)) {
            $subscription = $subscription->id;
        }

        my $invoiceitem = Net::Stripe::Invoiceitem->new(customer => $customer,
                                                        amount => $amount,
                                                        currency => $currency,
                                                        invoice => $invoice,
                                                        subscription => $subscription,
                                                        description => $description,
                                                        metadata => $metadata);
        return $self->_post('invoiceitems', $invoiceitem);
    }


    method post_invoiceitem(Net::Stripe::Invoiceitem|Str :$invoice_item,
                            Int :$amount?,
                            Str :$description?,
                            HashRef :$metadata?) {
        if (!defined($amount) && !defined($description) && !defined($metadata)) {
            my $item = $invoice_item->clone; $item->clear_currency;
            return $self->_post("invoiceitems/" . $item->id, $item);
        }

        if (ref($invoice_item)) {
            $invoice_item = $invoice_item->id;
        }

        return $self->_post("invoiceitems/" . $invoice_item,
                            {
                                amount => $amount,
                                description => $description,
                                metadata => $metadata
                            });
    }

    method get_invoiceitem(Str :$invoice_item) {
        return $self->_get("invoiceitems/$invoice_item");
    }

    method delete_invoiceitem(Net::Stripe::Invoiceitem|Str :$invoice_item) {
        if (ref($invoice_item)) {
            $invoice_item = $invoice_item->id;
        }
        $self->_delete("invoiceitems/$invoice_item");
    }

    method get_invoiceitems(HashRef :$created?,
                            Net::Stripe::Customer|Str :$customer?,
                            Str :$ending_before?,
                            Int :$limit?,
                            Str :$starting_after?) {
        if (ref($customer)) {
            $customer = $customer->id;
        }
        $self->_get_collections('invoiceitems',
                                created => $created,
                                ending_before => $ending_before,
                                limit => $limit,
                                starting_after => $starting_after
                            );
    }
}

# Helper methods

method _get(Str $path) {
    my $req = GET $self->api_base . '/' . $path;
    return $self->_make_request($req);
}

method _get_with_args(Str $path, $args?) {
    if (@$args) {
        $path .= "?" . join('&', @$args);
    }
    return $self->_get($path);
}

sub _get_collections {
    my $self = shift;
    my $path = shift;
    my %args = @_;
    my @path_args;
    if (my $c = $args{limit}) {
        push @path_args, "limit=$c";
    }
    if (my $o = $args{offset}) {
        push @path_args, "offset=$o";
    }
    if (my $c = $args{customer}) {
        push @path_args, "customer=$c";
    }

    # example: $Stripe->get_charges( 'count' => 100, 'created' => { 'gte' => 1397663381 } );
    if (defined($args{created})) {
      my %c = %{$args{created}};
      foreach my $key (keys %c) {
        if ($key =~ /(?:l|g)te?/) {
          push @path_args, "created[".$key."]=".$c{$key};
        }
      }
    }
    return $self->_get_with_args($path, \@path_args);
}

method _delete(Str $path) {
    my $req = DELETE $self->api_base . '/' . $path;
    return $self->_make_request($req);
}

sub convert_to_form_fields {
    my $hash = shift;
    if (ref($hash) eq 'HASH') {
        my $r = {};
        foreach my $key (grep { defined($hash->{$_}) }keys %$hash) {
            if (ref($hash->{$key}) =~ /^Net::Stripe/) {
                my %fields = $hash->{$key}->form_fields();
                foreach my $fn (keys %fields) {
                    $r->{$fn} = $fields{$fn};
                }
            } else {
                $r->{$key} = $hash->{$key};
            }
        }
        return $r;
    }
    return $hash;
}

method _post(Str $path, $obj?) {
    my $req = POST $self->api_base . '/' . $path,
        ($obj ? (Content => [ref($obj) eq 'HASH' ? %{convert_to_form_fields($obj)} : $obj->form_fields]) : ());
    return $self->_make_request($req);
}

method _make_request($req) {
    $req->header( Authorization =>
        "Basic " . encode_base64($self->api_key . ':'));

    if ($self->debug_network) {
        print STDERR "Sending to Stripe:\n------\n" . $req->as_string() . "------\n";

    }
    my $resp = $self->ua->request($req);

    if ($self->debug_network) {
        print STDERR "Received from Stripe:\n------\n" . $resp->as_string()  . "------\n";
    }

    if ($resp->code == 200) {
        return _hash_to_object(decode_json($resp->content));
    } elsif ($resp->code == 500) {
        die Net::Stripe::Error->new(
            type => "HTTP request error",
            code => $resp->code,
            message => $resp->status_line . " - " . $resp->content,
        );
    }

    my $e = eval {
        my $hash = decode_json($resp->content);
        Net::Stripe::Error->new($hash->{error})
    };
    if ($@) {
        Net::Stripe::Error->new(
            type => "Could not decode HTTP response: $@",
            message => $resp->status_line . " - " . $resp->content,
        );
    };

    warn "$e\n" if $self->debug;
    die $e;
}

sub _defined_arguments {
    my $args = shift;

    map { delete $args->{$_} } grep {  !defined($args->{$_}) } keys %$args;
    return $args;
}

sub _hash_to_object {
    my $hash   = shift;

    foreach my $k (grep { ref($hash->{$_}) } keys %$hash) {
        my $v = $hash->{$k};
        if (ref($v) eq 'HASH' && defined($v->{object})) {
            $hash->{$k} = _hash_to_object($v);
        } elsif (ref($v) =~ /^(JSON::XS::Boolean|JSON::PP::Boolean)$/) {
            $hash->{$k} = $v ? 1 : 0;
        }
    }

    if (defined($hash->{object})) {
        if ($hash->{object} eq 'list') {
            $hash->{data} = [map { _hash_to_object($_) } @{$hash->{data}}];
            return Net::Stripe::List->new($hash);
        }
        my @words  = map { ucfirst($_) } split('_', $hash->{object});
        my $object = join('', @words);
        my $class  = 'Net::Stripe::' . $object;
        return $class->new($hash);
    }
    return $hash;
}

method _build_api_base { 'https://api.stripe.com/v1' }

method _build_ua {
    my $ua = LWP::UserAgent->new(keep_alive => 4);
    $ua->agent("Net::Stripe/" . $Net::Stripe::VERSION);
    return $ua;
}

=head1 SEE ALSO

L<https://stripe.com>, L<https://stripe.com/docs/api>

=cut

__PACKAGE__->meta->make_immutable;
1;
