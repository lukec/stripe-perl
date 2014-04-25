package Net::Stripe;
use Moose;
use MooseX::Method::Signatures;
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
use Net::Stripe::SubscriptionList;
use Net::Stripe::Error;
use Net::Stripe::BalanceTransaction;

our $VERSION = '0.09';

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

has 'debug'         => (is => 'rw', isa => 'Bool',   default    => 0);
has 'debug_network' => (is => 'rw', isa => 'Bool',   default    => 0);
has 'api_key'       => (is => 'ro', isa => 'Str',    required   => 1);
has 'api_base'      => (is => 'ro', isa => 'Str',    lazy_build => 1);
has 'ua'            => (is => 'ro', isa => 'Object', lazy_build => 1);


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

=charge_method get_charge

Retrieve a charge.

L<https://stripe.com/docs/api#retrieve_charge>

=over 

=item * charge_id - Str - charge id to retrieve

=back

Returns L<Net::Stripe::Charge>

=charge_method refund_charge

Refunds a charge

L<https://stripe.com/docs/api#refund_charge>

=over 

=item * charge - L<Net::Stripe::Charge> or Str - charge or charge_id to refund

=item * amount - Int - amount to refund in cents, optional

=back

Returns a new L<Net::Stripe::Charge>.

=charge_method get_charges

Return a list of charges based on criteria.

L<https://stripe.com/docs/api#list_charges>

=over 

=item * created - HashRef - created conditions to match, optional

=item * customer - L<Net::Stripe::Customer> or Str - customer to match

=item * ending_before - Str - ending before condition, optional

=item * limit - Int - maximum number of charges to return, optional

=item * starting_after - Str - starting after condition, optional

=back

Returns a list of L<Net::Stripe::Charge> objects.

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
        
        if($amount) {
            $amount = "?amount=$amount";
        } else {
            $amount = '';
        }
        
        return $self->_post("charges/$charge/refund" . $amount);
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

=item * trial_end - Int, optional

Returns a L<Net::Stripe::Customer> object

=back

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

Returns a L<Net::Stripe::Customer> object

=customer_method delete_customer

Delete a customer

L<https://stripe.com/docs/api#delete_customer>

=over

=item * customer - L<Net::Stripe::Customer> or Str - the customer to delete

=back

Returns a L<Net::Stripe::Customer> object

=customer_method get_customers

Returns a list of customers.

L<https://stripe.com/docs/api#list_customers>

=over

=item * created - HashRef - created conditions, optional

=item * ending_before - Str, optional

=item * limit - Int, optional

=item * starting_after - Str, optional

=back

=cut

Customers: {
    method post_customer(Net::Stripe::Customer :$customer?,
                         Int :$account_balance?,
                         Net::Stripe::Card|Net::Stripe::Token|Str|HashRef :$card?,
                         Str :$coupon?,
                         Str :$description?,
                         Str :$email?, 
                         HashRef :$metadata?, 
                         Str :$plan?, 
                         Int :$quantity?, 
                         Int :$trial_end?) {
        if ($customer) {
            return $self->_post("customers/" . $customer->id, $customer);
        }

        if (defined($card) && ref($card) eq 'HASH') {
            $card = Net::Stripe::Card->new($card);
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
        return $self->_get("customers/$customer/subscriptions", 
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

=card_method post_card

Create or update a card

L<https://stripe.com/docs/api#create_card>

=over

=item * customer - L<Net::Stripe::Customer> or Str

=item * card - L<Net::Stripe::Card> or HashRef

=back

Returns a L<Net::Stripe::Card>

=card_method get_cards

Returns a list of cards

L<https://stripe.com/docs/api#list_cards>

=over

=item * customer - L<Net::Stripe::Customer> or Str 

=item * ending_before - Str, optional

=item * limit - Int, optional

=item * starting_after - Str, optional

=back

=card_method delete_card

Delete a card.

L<https://stripe.com/docs/api#delete_card>

=over

=item * customer - L<Net::Stripe::Customer> or Str

=item * card - L<Net::Stripe::Card> or Str

=back

Returns a L<Net::Stripe::Card>.

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
        return $self->_post("customers/$customer/cards/" . $card->id, $card);
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

=item * trial_end - Int, optional

=item * application_fee_percent - Int, optional

=back

Returns a L<Net::Stripe::Customer> object

=subscription_method get_subscription

Returns a customers subscription

=over

=item * customer - L<Net::Stripe::Customer> or Str

=back

Returns a L<Net::Stripe::Subscription>

=subscription_method delete_subscription

Cancel a customer's subscription

L<https://stripe.com/docs/api#cancel_subscription>

=over

=item * customer - L<Net::Stripe::Customer> or Str 

=item * subscription - L<Net::Stripe::Subscription> or Str 

=item * at_period_end - Bool, optional

=back

Returns a L<Net::Stripe::Subscription> object.

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
                             Int :$trial_end?,
                             Net::Stripe::Card|Net::Stripe::Token|Str|HashRef :$card?,
                             Int :$quantity?,
                             Num :$application_fee_percent?
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
                    quantity => $quantity,
                    application_fee_percent => $application_fee_percent);

        map { delete $args{$_} } grep {  !defined($args{$_}) } keys %args;

        if (ref($subscription) && $subscription eq 'Net::Stripe::Subscription') {
            return $self->_post("customers/$customer/subscriptions/" . $subscription->id, $subscription);
        } elsif (defined($subscription) && !ref($subscription)) {
            return $self->_post("customers/$customer/subscriptions/" . $subscription, \%args);
        }
        
        return $self->_post("customers/$customer/subscriptions", \%args);
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

=token_method get_token

Retreives an existing token.

L<https://stripe.com/docs/api#retrieve_token>

=over

=item token_id - Str

=back

Returns a L<Net::Stripe::Token>

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

=plan_method get_plan

Retrieves a plan.

=over

=item * plan_id - Str

=back

Returns a L<Net::Stripe::Plan>

=plan_method delete_plan

Delete a plan.

L<https://stripe.com/docs/api#delete_plan>

=over

=item * plan_id - L<Net::Stripe::Plan> or Str

=back

Returns a L<Net::Stripe::Plan> object

=plan_method get_plans

Return a list of Plans

L<https://stripe.com/docs/api#list_plans>

=over

=item * ending_before - Str, optional

=item * limit - Int, optional

=item * starting_after - Str, optional

=back

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

Create a coupon

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

=coupon_method get_coupon

Retreive a coupon

L<https://stripe.com/docs/api#retrieve_coupon>

=over

=item * coupon_id - Str

=back

=coupon_method delete_coupon

Delete a coupon

L<https://stripe.com/docs/api#delete_coupon>

=over

=item * coupon_id - Str

=back

Returns a L<Net::Stripe::Coupon>

=coupon_method get_coupons

=over

=item * ending_before - Str, optional

=item * limit - Int, optional

=item * starting_after - Str, optional

=back

Returns a list of L<Net::Stripe::Coupon>

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


=invoice_method post_invoice

Create a new invoice

L<https://stripe.com/docs/api#create_invoice>

=over

=item * invoice - L<Net::Stripe::Invoice>, Str 

=item * application_fee - Int - optional

=item * closed - Bool - optional

=item * description - Str - optional

=item * metadata - HashRef - optional

=back

Returns a L<Net::Stripe::Invoice>

=invoice_method get_invoice

=over

=item * invoice_id - Str

=back

Returns a L<Net::Stripe::Invoice>

=invoice_method get_upcominginvoice( COUPON_ID )

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

Returns a list of L<Net::Stripe::Invoices>

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

=invoice_method get_invoice

=over

=item * invoice_id - Str

=back

Returns a L<Net::Stripe::Invoice>


=invoice_method get_upcominginvoice

=over

=item * customer, Net::Stripe::Cusotmer or Str

=back

Returns a L<Net::Stripe::Invoice>

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
                            customer => $customer,
                            application_fee => $application_fee,
                            description => $description,
                            metadata => $metadata,
                            subscription =>$subscription);
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
                            application_fee => $application_fee,
                            closed => $closed,
                            description => $description,
                            metadata => $metadata
                        );
    }

    method get_invoice(Str :$invoice_id) {
        return $self->_get("invoices/$invoice_id");
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

=invoiceitem_method create_invoiceitem( PARAMHASH | OBJECT )

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

=invoiceitem_method post_invoiteitem

Update an invoice item.

L<https://stripe.com/docs/api#create_invoiceitem>

=over

=item * invoice_item - L<Net::Stripe::Invoiceitem> or Str

=item * amount - Int, optional

=item * description - Str, optional

=item * metadata - HashRef, optional

=back

Returns a L<Net::Stripe::Invoiceitem>

=invoiceitem_method get_invoiceitem

Retrieve an invoice item.

=over

=item * invoice_item - Str

=back

Returns a L<Net::Stripe::Invoiceitem>

=invoiceitem_method delete_invoiceitem

Delete an invoice item

=over

=item * invoice_item - L<Net::Stripe::Invoiceitem> or Str

=back

Returns a L<Net::Stripe::Invoiceitem>

=invoiceitem_method get_invoiceitems

=over

=item * customer - L<Net::Stripe::Customer> or Str, optional

=item * date - Int or HashRef, optional

=item * ending_before - Str, optional

=item * limit - Int, optional

=item * starting_after - Str, optional

=back

Returns a list of L<Net::Stripe::Invoiceitem> objects

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
                            amount => $amount,
                            description => $description,
                            metadata => $metadata);
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

method _post(Str $path, $obj?) {
    my $req = POST $self->api_base . '/' . $path, 
        ($obj ? (Content => [ref($obj) eq 'HASH' ? %$obj : $obj->form_fields]) : ());
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
        my $hash = decode_json($resp->content);
        if( $hash->{object} && 'list' eq $hash->{object} ) {
          my @objects = ();
          foreach my $object_data (@{$hash->{data}}) {
            push @objects, hash_to_object($object_data);            
          }
          return \@objects;
        }     
        return hash_to_object($hash) if $hash->{object};
        if (my $data = $hash->{data}) {
            return [ map { hash_to_object($_) } @$data ];
        }
        return $hash;
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


sub hash_to_object {
    my $hash   = shift;
    my @words  = map { ucfirst($_) } split('_', $hash->{object});
    my $object = join('', @words);
    my $class  = 'Net::Stripe::' . $object;
    return $class->new($hash);
}

method _build_api_base { 'https://api.stripe.com/v1' }

method _build_ua {
    my $ua = LWP::UserAgent->new();
    $ua->agent("Net::Stripe/$VERSION");
    return $ua;
}

=head1 SEE ALSO

L<https://stripe.com>, L<https://stripe.com/docs/api>

=head1 CONTRIBUTORS

=cut

__PACKAGE__->meta->make_immutable;
1;
