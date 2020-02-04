package Net::Stripe;

use Moose;
use Class::Load;
use Kavorka;
use LWP::UserAgent;
use HTTP::Request::Common qw/GET POST DELETE/;
use MIME::Base64 qw/encode_base64/;
use URI::Escape qw/uri_escape/;
use JSON qw/decode_json/;
use Net::Stripe::TypeConstraints;
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

 # ... and the API mirrors https://stripe.com/docs/api
 # Charges: post_charge() get_charge() refund_charge() get_charges()
 # Customer: post_customer()

=head1 DESCRIPTION

This module is a wrapper around the Stripe.com HTTP API.  Methods are
generally named after the HTTP method and the object name.

This method returns Moose objects for responses from the API.

=head2 WARNING

This SDK is "version agnostic" of the Stripe API
L<https://github.com/lukec/stripe-perl/issues/80>
and at the time of this release Stripe has some major changes afoot
L<https://github.com/lukec/stripe-perl/issues/115>

If you're considering using this please click "Watch" on this github project
L<https://github.com/lukec/stripe-perl/>
where discussion on these topics takes place.

=head1 RELEASE NOTES

=head2 Version 0.40

=head3 BREAKING CHANGES

=over

=item deprecate direct handling of PANs

Stripe strongly discourages direct handling of PANs (primary account numbers),
even in test mode, and returns invalid_request_error when passing PANs to the
API from accounts that were created after October 2017. In live mode, all
tokenization should be performed via client-side libraries because direct
handling of PANs violates PCI compliance. So we have removed the methods and
parameter constraints that allow direct handling of PANs and updated the
unit tests appropriately.

=back

=head3 BUG FIXES

=over

=item fix post_charge() arguments

Some argument types for `customer` and `card` were non-functional in the
current code and have been removed from the Kavorka method signature. We
removed `Net::Stripe::Customer` and `HashRef` for `customer` and we removed
`Net::Stripe::Card` and `Net::Stripe::Token` for `card`, as none of these
forms were being serialized correctly for passing to the API call. We must
retain `Net::Stripe::Card` for the `card` attribute in `Net::Stripe::Charge`
because the `card` value returned from the API call is objectified into
a card object. We have also added TypeConstraints for the string arguments
passed and added in-method validation to ensure that the passed argument
values make sense in the context of one another.

=item cleanup post_card()

Some argument types for `card` are not legitimate, or are being deprecated
and have been removed from the Kavorka method signature. We removed
`Net::Stripe::Card` and updated the string validation to disallow card id
for `card`, as neither of these are legitimate when creating or updating a
card L<https://github.com/lukec/stripe-perl/issues/138>, and the code path
that appeared to be handling `Net::Stripe::Card` was actually unreachable
L<https://github.com/lukec/stripe-perl/issues/100>. We removed the dead code
paths and made the conditional structure more explicit, per discussion in
<https://github.com/lukec/stripe-perl/pull/133>. We also added unit tests
for all calling forms, per <https://github.com/lukec/stripe-perl/issues/139>.

=item fix post_customer() arguments

Some argument types for `card` are not legitimate and have been removed from
the Kavorka method signature. We removed `Net::Stripe::Card` and updated the
string validation to disallow card id for `card`, as neither of these are
legitimate when creating or updating a customer L<https://github.com/lukec/stripe-perl/issues/138>.
We have also updated the structure of the method so that we always create a
Net::Stripe::Customer object before posting L<https://github.com/lukec/stripe-perl/issues/148>
and cleaned up and centralized Net::Stripe:Token coercion code.

=back

=head3 ENHANCEMENTS

=over

=item coerce old lists

In older Stripe API versions, some list-type data structures were returned
as arrayrefs. We now coerce those old-style lists and collections into the
hashref format that newer versions of the API return, with metadata stored
top-level keys and the list elements in an arrayref with the key 'data',
which is the format that C<Net::Stripe::List> expects. This makes the SDK
compatible with the Stripe API back to the earliest documented API version
<https://stripe.com/docs/upgrades#2011-06-21>.

=item add update_card()

This method allows updates to card address, expiration, metadata, etc for
existing customer cards.

=item encode card metdata in convert_to_form_fields()

When passing a hashref with a nested metadata hashref to _post(), that
metadata must be encoded properly before being passed to the Stripe API.
There is now a dedicated block in convert_to_form_fields for this operation.
This update was necessary because of the addition of update_card(), which
accepts a card hashref, which may include metadata.

=back

=head3 UPDATES

=over

=item update statement_description to statement_descriptor

The statement_description attribute is now statement_descriptor for
L<Net::Stripe::Charge> and L<Net::Stripe::Plan>. The API docs
L<https://stripe.com/docs/upgrades#2014-12-17> indicate that this change
is backwards-compatible. You must update your code to reflect this change
for parameters passed to these objects and methods called on these objects.

=item update unit tests for Charge->status

For Stripe API versions after 2015-02-18 L<https://stripe.com/docs/upgrades#2015-02-18>,
the status property on the Charge object has a value of 'succeeded' for
successful charges. Previously, the status property would be 'paid' for
successful charges. This change does not affect the API calls themselves, but
if your account is using Stripe API version 2015-02-18 or later, you should
update any code that relies on strict checking of the return value of
Charge->status.

=back

=method new PARAMHASH

This creates a new stripe API object.  The following parameters are accepted:

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

Create a new charge.

L<https://stripe.com/docs/api#create_charge>

=over

=item * amount - Int - amount to charge

=item * currency - Str - currency for charge

=item * customer - StripeCustomerId - customer to charge - optional

=item * card - StripeTokenId or StripeCardId - card to use - optional

=item * description - Str - description for the charge - optional

=item * metadata - HashRef - metadata for the charge - optional

=item * capture - Bool - optional

=item * statement_descriptor - Str - descriptor for statement - optional

=item * application_fee - Int - optional

=item * receipt_email - Str - The email address to send this charge's receipt to - optional

=back

Returns L<Net::Stripe::Charge>.

  $stripe->post_charge(currency => 'USD', amount => 500, customer => 'testcustomer');

=charge_method get_charge

Retrieve a charge.

L<https://stripe.com/docs/api#retrieve_charge>

=over

=item * charge_id - Str - charge id to retrieve

=back

Returns L<Net::Stripe::Charge>.

  $stripe->get_charge(charge_id => 'chargeid');

=charge_method refund_charge

Refunds a charge.

L<https://stripe.com/docs/api#create_refund>

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

=charge_method capture_charge

L<https://stripe.com/docs/api/charges/capture#capture_charge>

=over

=item * charge - L<Net::Stripe::Charge> or Str - charge to capture

=back

Returns a L<Net::Stripe::Charge>.

  $stripe->capture_charge(charge => $charge_id);

=cut

Charges: {
    method post_charge(Int :$amount,
                       Str :$currency,
                       StripeCustomerId :$customer?,
                       StripeTokenId|StripeCardId :$card?,
                       Str :$description?,
                       HashRef :$metadata?,
                       Bool :$capture?,
                       Str :$statement_descriptor?,
                       Int :$application_fee?,
                       Str :$receipt_email?
                     ) {

        if ( defined( $card ) ) {
            my $card_id_type = Moose::Util::TypeConstraints::find_type_constraint( 'StripeCardId' );
            if ( defined( $customer ) && ! $card_id_type->check( $card ) ) {
                die Net::Stripe::Error->new(
                    type => "post_charge error",
                    message => sprintf(
                        "Invalid value '%s' passed for parameter 'card'. Charges for an existing customer can only accept a card id.",
                        $card,
                    ),
                );
            }

            my $token_id_type = Moose::Util::TypeConstraints::find_type_constraint( 'StripeTokenId' );
            if ( ! defined( $customer ) && ! $token_id_type->check( $card ) ) {
                die Net::Stripe::Error->new(
                    type => "post_charge error",
                    message => sprintf(
                        "Invalid value '%s' passed for parameter 'card'. Charges without an existing customer can only accept a token id.",
                        $card,
                    ),
                );
            }
        }

        my $charge = Net::Stripe::Charge->new(amount => $amount,
                                              currency => $currency,
                                              customer => $customer,
                                              card => $card,
                                              description => $description,
                                              metadata => $metadata,
                                              capture => $capture,
                                              statement_descriptor => $statement_descriptor,
                                              application_fee => $application_fee,
                                              receipt_email => $receipt_email
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

    method capture_charge(Net::Stripe::Charge|Str :$charge) {
        if (ref($charge)) {
            $charge = $charge->id;
        }

        return $self->_post("charges/$charge/capture");
    }

}

=balance_transaction_method get_balance_transaction

Retrieve a balance transaction.

L<https://stripe.com/docs/api#retrieve_balance_transaction>

=over

=item * id - Str - balance transaction ID to retrieve.

=back

Returns a L<Net::Stripe::BalanceTransaction>.

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

=item * customer - L<Net::Stripe::Customer> or StripeCustomerId - existing customer to update, optional

=item * account_balance - Int, optional

=item * card - L<Net::Stripe::Token> or StripeTokenId, default card for the customer, optional

=item * coupon - Str, optional

=item * description - Str, optional

=item * email - Str, optional

=item * metadata - HashRef, optional

=item * plan - Str, optional

=item * quantity - Int, optional

=item * trial_end - Int or Str, optional

=back

Returns a L<Net::Stripe::Customer> object.

  my $customer = $stripe->post_customer(
    card => $token_id,
    email => 'stripe@example.com',
    description => 'Test for Net::Stripe',
  );

=customer_method list_subscriptions

Returns the subscriptions for a customer.

L<https://stripe.com/docs/api#list_subscriptions>

=over

=item * customer - L<Net::Stripe::Customer> or Str

=item * ending_before - Str, optional

=item * limit - Int, optional

=item * starting_after - Str, optional

=back

Returns a list of L<Net::Stripe::Subscription> objects.

=customer_method get_customer

Retrieve a customer.

L<https://stripe.com/docs/api#retrieve_customer>

=over

=item * customer_id - Str - the customer id to retrieve

=back

Returns a L<Net::Stripe::List> object containing L<Net::Stripe::Customer> objects.

  $stripe->get_customer(customer_id => $id);

=customer_method delete_customer

Delete a customer.

L<https://stripe.com/docs/api#delete_customer>

=over

=item * customer - L<Net::Stripe::Customer> or Str - the customer to delete

=back

Returns a L<Net::Stripe::Customer> object.

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
    method post_customer(Net::Stripe::Customer|StripeCustomerId :$customer?,
                         Int :$account_balance?,
                         Net::Stripe::Token|StripeTokenId :$card?,
                         Str :$coupon?,
                         Str :$default_card?,
                         Str :$description?,
                         Str :$email?,
                         HashRef :$metadata?,
                         Str :$plan?,
                         Int :$quantity?,
                         Int|Str :$trial_end?) {

        my $customer_obj;
        if ( ref( $customer ) ) {
            $customer_obj = $customer;
        } else {
            my %args = (
                account_balance => $account_balance,
                card => $card,
                coupon => $coupon,
                default_card => $default_card,
                email => $email,
                metadata => $metadata,
                plan => $plan,
                quantity => $quantity,
                trial_end => $trial_end,
            );
            $args{id} = $customer if defined( $customer );

            $customer_obj = Net::Stripe::Customer->new( %args );
        }

        if ( my $customer_id = $customer_obj->id ) {
            return $self->_post("customers/$customer_id", $customer_obj);
        } else {
            return $self->_post('customers', $customer_obj);
        }
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

    method get_customers(HashRef :$created?, Str :$ending_before?, Int :$limit?, Str :$starting_after?, Str :$email?) {
        $self->_get_collections('customers',
                                created => $created,
                                ending_before => $ending_before,
                                limit => $limit,
                                starting_after => $starting_after,
                                email => $email,
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

Returns a L<Net::Stripe::Card>.

  $stripe->get_card(customer => 'customer_id', card_id => 'abcdef');

=card_method post_card

Create a card.

L<https://stripe.com/docs/api/cards/create#create_card>

=over

=item * customer - L<Net::Stripe::Customer> or StripeCustomerId

=item * card - L<Net::Stripe::Token> or StripeTokenId

=back

Returns a L<Net::Stripe::Card>.

  $stripe->post_card(customer => $customer, card => $card);

=card_method update_card

Update a card.

L<https://stripe.com/docs/api/cards/update#update_card>

=over

=item * customer_id - StripeCustomerId

=item * card_id - StripeCardId

=item * card - HashRef

=back

Returns a L<Net::Stripe::Card>.

  $stripe->update_card(
      customer_id => $customer_id,
      card_id => $card_id,
      card => {
          name => $new_name,
          metadata => {
              'account-number' => $new_account_nunmber,
          },
      },
  );

=card_method get_cards

Returns a list of cards.

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

    method get_cards(Net::Stripe::Customer|Str :$customer,
                     HashRef :$created?,
                     Str :$ending_before?,
                     Int :$limit?,
                     Str :$starting_after?) {
        if (ref($customer)) {
            $customer = $customer->id;
        }

        $self->_get_collections("customers/$customer/sources",
                                object => "card",
                                created => $created,
                                ending_before => $ending_before,
                                limit => $limit,
                                starting_after => $starting_after);
    }

    method post_card(Net::Stripe::Customer|StripeCustomerId :$customer!,
                     Net::Stripe::Token|StripeTokenId :$card!) {
        my $customer_id = ref( $customer ) ? $customer->id : $customer;
        if ( ref( $card ) eq 'HASH' ) {
            my $card_obj = Net::Stripe::Card->new( $card );
            return $self->_post("customers/$customer_id/cards", $card_obj);
        } else {
            # card here is either Net::Stripe::Token or StripeTokenId
            my $token_id = ref( $card ) ? $card->id : $card;
            return $self->_post("customers/$customer_id/cards", {card=> $token_id});
        }
    }

    method update_card(StripeCustomerId :$customer_id!,
                     StripeCardId :$card_id!,
                     HashRef :$card!) {
        return $self->_post("customers/$customer_id/cards/$card_id", $card);
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

=item * card - L<Net::Stripe::Card>, L<Net::Stripe::Token> or Str, default card for the customer, optional

=item * coupon - Str, optional

=item * description - Str, optional

=item * plan - Str, optional

=item * quantity - Int, optional

=item * trial_end - Int, or Str optional

=item * application_fee_percent - Int, optional

=item * prorate - Bool, optional

=back

Returns a L<Net::Stripe::Customer> object.

  $stripe->post_subscription(customer => $customer, plan => 'testplan');

=subscription_method get_subscription

Returns a customer's subscription.

=over

=item * customer - L<Net::Stripe::Customer> or Str

=back

Returns a L<Net::Stripe::Subscription>.

  $stripe->get_subscription(customer => 'test123');

=subscription_method delete_subscription

Cancel a customer's subscription.

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
                             Net::Stripe::Card|Net::Stripe::Token|Str :$card?,
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

        if (ref($subscription) ne 'Net::Stripe::Subscription') {
            my %args = (plan => $plan,
                        coupon => $coupon,
                        trial_end => $trial_end,
                        card => $card,
                        prorate => $prorate,
                        quantity => $quantity,
                        application_fee_percent => $application_fee_percent);
            if (defined($subscription)) {
                $args{id} = $subscription;
            }
            $subscription = Net::Stripe::Subscription->new( %args );
        }

        if (defined($subscription->id)) {
            return $self->_post("customers/$customer/subscriptions/" . $subscription->id, $subscription);
        } else {
            return $self->_post("customers/$customer/subscriptions", $subscription);
        }
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

=token_method get_token

Retrieves an existing token.

L<https://stripe.com/docs/api#retrieve_token>

=over

=item * token_id - Str

=back

Returns a L<Net::Stripe::Token>.

  $stripe->get_token(token_id => 'testtokenid');

=cut

Tokens: {
    method get_token(Str :$token_id) {
        return $self->_get("tokens/$token_id");
    }
}

=plan_method post_plan

Create a new plan.

L<https://stripe.com/docs/api#create_plan>

=over

=item * id - Str - identifier of the plan

=item * amount - Int - cost of the plan in cents

=item * currency - Str

=item * interval - Str

=item * interval_count - Int - optional

=item * name - Str - name of the plan

=item * trial_period_days - Int - optional

=item * statement_descriptor - Str - optional

=back

Returns a L<Net::Stripe::Plan> object.

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

Returns a L<Net::Stripe::Plan>.

  $stripe->get_plan(plan_id => 'plan123');

=plan_method delete_plan

Delete a plan.

L<https://stripe.com/docs/api#delete_plan>

=over

=item * plan_id - L<Net::Stripe::Plan> or Str

=back

Returns a L<Net::Stripe::Plan> object.

  $stripe->delete_plan(plan_id => $plan);

=plan_method get_plans

Return a list of plans.

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
                     Str :$statement_descriptor?) {
        my $plan = Net::Stripe::Plan->new(id => $id,
                                          amount => $amount,
                                          currency => $currency,
                                          interval => $interval,
                                          interval_count => $interval_count,
                                          name => $name,
                                          trial_period_days => $trial_period_days,
                                          metadata => $metadata,
                                          statement_descriptor => $statement_descriptor);
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

Create or update a coupon.

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

Retrieve a coupon.

L<https://stripe.com/docs/api#retrieve_coupon>

=over

=item * coupon_id - Str

=back

Returns a L<Net::Stripe::Coupon> object.

  $stripe->get_coupon(coupon_id => 'id');

=coupon_method delete_coupon

Delete a coupon.

L<https://stripe.com/docs/api#delete_coupon>

=over

=item * coupon_id - Str

=back

Returns a L<Net::Stripe::Coupon>.

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

Deletes a customer-wide discount.

L<https://stripe.com/docs/api/curl#delete_discount>

=over

=item * customer - L<Net::Stripe::Customer> or Str - the customer with a discount to delete

=back

  $stripe->delete_customer_discount(customer => $customer);

Returns hashref of the form

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

Update an invoice.

=over

=item * invoice - L<Net::Stripe::Invoice>, Str

=item * application_fee - Int - optional

=item * closed - Bool - optional

=item * description - Str - optional

=item * metadata - HashRef - optional

=back

Returns a L<Net::Stripe::Invoice>.

  $stripe->post_invoice(invoice => $invoice, closed => 1)

=invoice_method get_invoice

=over

=item * invoice_id - Str

=back

Returns a L<Net::Stripe::Invoice>.

  $stripe->get_invoice(invoice_id => 'testinvoice');

=invoice_method pay_invoice

=over

=item * invoice_id - Str

=back

Returns a L<Net::Stripe::Invoice>.

  $stripe->pay_invoice(invoice_id => 'testinvoice');

=invoice_method get_invoices

Returns a list of invoices.

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

Create a new invoice.

L<https://stripe.com/docs/api#create_invoice>

=over

=item * customer - L<Net::Stripe::Customer>, Str

=item * application_fee - Int - optional

=item * description - Str - optional

=item * metadata - HashRef - optional

=item * subscription - L<Net::Stripe::Subscription> or Str, optional

=back

Returns a L<Net::Stripe::Invoice>.

  $stripe->create_invoice(customer => 'custid', description => 'test');

=invoice_method get_invoice

=over

=item * invoice_id - Str

=back

Returns a L<Net::Stripe::Invoice>.

  $stripe->get_invoice(invoice_id => 'test');

=invoice_method get_upcominginvoice

=over

=item * customer, L<Net::Stripe::Cusotmer> or Str

=back

Returns a L<Net::Stripe::Invoice>.

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

Returns a L<Net::Stripe::Invoiceitem> object.

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

Returns a L<Net::Stripe::Invoiceitem>.

  $stripe->post_invoiceitem(invoice_item => 'itemid', amount => 750);

=invoiceitem_method get_invoiceitem

Retrieve an invoice item.

=over

=item * invoice_item - Str

=back

Returns a L<Net::Stripe::Invoiceitem>.

  $stripe->get_invoiceitem(invoice_item => 'testitemid');

=invoiceitem_method delete_invoiceitem

Delete an invoice item.

=over

=item * invoice_item - L<Net::Stripe::Invoiceitem> or Str

=back

Returns a L<Net::Stripe::Invoiceitem>.

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
    if (my $c = $args{object}) {
        push @path_args, "object=$c";
    }
    if (my $c = $args{ending_before}) {
        push @path_args, "ending_before=$c";
    }
    if (my $c = $args{starting_after}) {
        push @path_args, "starting_after=$c";
    }
    if (my $e = $args{email}) {
        push @path_args, "email=$e";
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
            } elsif ($key eq 'metadata' && ref($hash->{$key}) eq 'HASH') {
                foreach my $fn (keys %{$hash->{$key}}) {
                    $r->{$key . '[' . $fn . ']'} = $hash->{$key}->{$fn};
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
        my $ref = decode_json( $resp->content );
        if ( ref( $ref ) eq 'ARRAY' ) {
            # some list-type data structures are arrayrefs in API versions 2012-09-24 and earlier.
            # if those data structures are at the top level, such as when
            # we request 'GET /charges/cus_.../', we need to coerce that
            # arrayref into the form that Net::Stripe::List expects.
            return _array_to_object( $ref, $req->uri );
        } elsif ( ref( $ref ) eq 'HASH' ) {
            # all top-level data structures are hashes in API versions 2012-10-26 and later
            return _hash_to_object( $ref );
        } else {
            die Net::Stripe::Error->new(
                type => "HTTP request error",
                message => sprintf(
                    "Invalid object type returned: '%s'",
                    ref( $ref ) || 'NONREF',
                ),
            );
        }
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

sub _hash_to_object {
    my $hash   = shift;

    if ( exists( $hash->{deleted} ) && exists( $hash->{object} ) && $hash->{object} ne 'customer' ) {
      delete( $hash->{object} );
    }

    # coerce pre-2011-08-01 API arrayref list format into a hashref
    # compatible with Net::Stripe::List
    $hash = _pre_2011_08_01_processing( $hash );

    # coerce pre-2012-10-26 API invoice lines format into a hashref
    # compatible with Net::Stripe::List
    $hash = _pre_2012_10_26_processing( $hash );

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
        if (Class::Load::is_class_loaded($class)) {
          return $class->new($hash);
        }
    }
    return $hash;
}

sub _array_to_object {
    my ( $array, $uri ) = @_;
    my $list = _array_to_list( $array );
    # strip the protocol, domain and query args in order to mimic the
    # url returned with Stripe lists in API versions 2012-10-26 and later
    $uri =~ s#\?.*$##;
    $uri =~ s#^https://[^/]+##;
    $list->{url} = $uri;
    return _hash_to_object( $list );
}

sub _array_to_list {
    my $array = shift;
    my $count = scalar( @$array );
    my $list = {
        object => 'list',
        count => $count,
        has_more => 0,
        data => $array,
        total_count => $count,
    };
    return $list;
}

# coerce pre-2011-08-01 API arrayref list format into a hashref
# compatible with Net::Stripe::List
sub _pre_2011_08_01_processing {
    my $hash = shift;
    foreach my $type ( qw/ cards subscriptions / ) {
        if ( exists( $hash->{$type} ) && ref( $hash->{$type} ) eq 'ARRAY' ) {
            $hash->{$type} = _array_to_list( delete( $hash->{$type} ) );
            my $customer_id;
            if ( exists( $hash->{object} ) && $hash->{object} eq 'customer' && exists( $hash->{id} ) ) {
                $customer_id = $hash->{id};
            } elsif ( exists( $hash->{customer} ) ) {
                $customer_id = $hash->{customer};
            }
            # Net::Stripe::List->new() will fail without url, but we
            # can make debugging easier by providing a message here
            die Net::Stripe::Error->new(
                type => "object coercion error",
                message => sprintf(
                    "Could not determine customer id while coercing %s list into Net::Stripe::List.",
                    $type,
                ),
            ) unless $customer_id;

            # mimic the url sent with standard Stripe lists
            $hash->{$type}->{url} = "/v1/customers/$customer_id/$type";
        }
    }
    return $hash;
}

# coerce pre-2012-10-26 API invoice lines format into a hashref
# compatible with Net::Stripe::List
sub _pre_2012_10_26_processing {
    my $hash = shift;
    if (
        exists( $hash->{object} ) && $hash->{object} eq 'invoice' &&
        exists( $hash->{lines} ) && ref( $hash->{lines} ) eq 'HASH' &&
        ! exists( $hash->{lines}->{object} )
    ) {
        my $data = [];
        my $lines = delete( $hash->{lines} );
        foreach my $key ( sort( keys( %$lines ) ) ) {
            my $ref = $lines->{$key};
            unless ( ref( $ref ) eq 'ARRAY' ) {
                die Net::Stripe::Error->new(
                    type => "object coercion error",
                    message => sprintf(
                        "Found invalid subkey type '%s' while coercing invoice lines into a Net::Stripe::List.",
                        ref( $ref ),
                    ),
                );
            }
            foreach my $item ( @$ref ) {
                push @$data, $item;
            }
        }
        $hash->{lines} = _array_to_list( $data );

        my $customer_id;
        if ( exists( $hash->{customer} ) ) {
            $customer_id = $hash->{customer};
        }
        # Net::Stripe::List->new() will fail without url, but we
        # can make debugging easier by providing a message here
        die Net::Stripe::Error->new(
            type => "object coercion error",
            message => "Could not determine customer id while coercing invoice lines into Net::Stripe::List.",
        ) unless $customer_id;

        # mimic the url sent with standard Stripe lists
        $hash->{lines}->{url} = "/v1/invoices/upcoming/lines?customer=$customer_id";
    }
    return $hash;
}

method _build_api_base { 'https://api.stripe.com/v1' }

method _build_ua {
    my $ua = LWP::UserAgent->new(keep_alive => 4);
    $ua->agent("Net::Stripe/" . ($Net::Stripe::VERSION || 'dev'));
    return $ua;
}

=head1 SEE ALSO

L<https://stripe.com>, L<https://stripe.com/docs/api>

=encoding UTF-8

=cut

__PACKAGE__->meta->make_immutable;
1;
