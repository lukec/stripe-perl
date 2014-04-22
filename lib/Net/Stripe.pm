package Net::Stripe;
use Moose;
use methods;
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
use Net::Stripe::Subscription;
use Net::Stripe::SubscriptionList;
use Net::Stripe::Error;
use Net::Stripe::BalanceTransaction;

our $VERSION = '0.09';

=head1 NAME

Net::Stripe - API client for Stripe.com

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
 my $same_charge = $stripe->get_charge($charge->id);

 # ... and the api mirrors https://stripe.com/docs/api
 # Charges: post_charge() get_charge() refund_charge() get_charges()
 # Customer: post_customer() 

=head1 DESCRIPTION

This module is a wrapper around the Stripe.com HTTP API.  Methods are 
generally named after the HTTP method and the object name.

This method returns Moose objects for responses from the API.

=head1 METHODS

=head2 API Object

=head3 new PARAMHASH

This creates a new stripe api object.  The following parameters are accepted:

=over

=item api_key

This is required. You get this from your Stripe Account settings.

=item debug

You can set this to true to see extra debug info.

=back
 
=cut

has 'debug'         => (is => 'rw', isa => 'Bool',   default    => 0);
has 'debug_network' => (is => 'rw', isa => 'Bool',   default    => 0);
has 'api_key'       => (is => 'ro', isa => 'Str',    required   => 1);
has 'api_base'      => (is => 'ro', isa => 'Str',    lazy_build => 1);
has 'ua'            => (is => 'ro', isa => 'Object', lazy_build => 1);

=head2 Charges

All methods accept the same arguments as described in the API.

See https://stripe.com/docs/api for full details.

=head3 post_charge( PARAMHASH | OBJECT )

=head3 get_charge( CHARGE_ID )

=head3 refund_charge( CHARGE_ID )

=head3 get_charges( PARAMHASH )

=cut

Charges: {
    method post_charge {
        my %args = @_;
        my $charge = Net::Stripe::Charge->new(%args);
        return $self->_post('charges', $charge);
    }

    method get_charge {
        my $id = shift || die "A charge ID is required";
        return $self->_get("charges/$id");
    }

    method refund_charge {
        my $id = shift || die "A charge ID is required";
        my $amount = shift;
        $id = $id->id if ref($id);
        
        if($amount) {
            $amount = "?amount=$amount";
        } else {
            $amount = '';
        }
        
        return $self->_post("charges/$id/refund" . $amount);
    }

    method get_charges {
        my %args = @_;
        $self->_get_collections('charges', %args);
    }
    
    
}

BalanceTransactions: {
  method get_balance_transaction {
    my $id = shift || die "A transaction ID is required";
    return $self->_get("balance/history/$id");
  }
}

=head2 Customers

All methods accept the same arguments as described in the API.

See https://stripe.com/docs/api for full details.

=head3 post_customer( PARAMHASH | OBJECT )

=head3 get_customer( CUSTOMER_ID )

=head3 delete_customer( CUSTOMER_ID )

=head3 post_customer_subscription( CUSTOMER_ID, PARAMHASH )

=head3 get_customers( PARAMHASH )

=cut

Customers: {
    method post_customer {
        # Update from an existing object
        if (@_ == 1) {
            my $c = shift;
            return $self->_post("customers/" . $c->id, $c);
        }

        my $customer = Net::Stripe::Customer->new(@_);
        return $self->_post('customers', $customer);
    }

    # adds a subscription, keeping any existing subscriptions unmodified
    method post_customer_subscription {
        my $customer_id = shift || die 'post_customer_subscription() requires a customer_id';
        die 'post_customer_subscription() requires a param hash' unless @_;
        $self->_post("customers/$customer_id/subscriptions", @_);
    }

    method list_subscriptions {
        my %args = @_;
        my $cid = delete $args{customer_id};
        return $self->_get("customers/$cid/subscriptions", @_);
    }

    method get_customer {
        my $id = shift || die 'get_customer() requires a customer id';
        return $self->_get("customers/$id");
    }

    method delete_customer {
        my $id = shift || die 'delete_customer() requires a customer id';
        $id = $id->id if ref($id);
        $self->_delete("customers/$id");
    }

    method get_customers {
        $self->_get_collections('customers', @_);
    }
}

=head2 Cards

All methods accept the same arguments as described in the API.

See https://stripe.com/docs/api for full details.

=head3 post_card( PARAMHASH )

=head3 get_card( customer_id => CUSTOMER_ID, card_id => CARD_ID )

=head3 get_cards( customer_id => CUSTOMER_ID)

=head3 update_card( customer_id => CUSTOMER_ID, card_id => CARD_ID)

=head3 delete_card( customer_id => CUSTOMER_ID, card_id => CARD_ID )

=cut

Cards: {
    method get_card {
        my %args = @_;
        my $cid = delete $args{customer_id};
        my $card_id = delete $args{card_id};
        return $self->_get("customers/$cid/cards/$card_id");
    }

    method get_cards {
        $self->_get_collections('cards', @_);
    }

    method post_card {
        my %args = @_;
        my $cid = delete $args{customer_id};
        my $card = Net::Stripe::Card->new(%args);
        return $self->_post("customers/$cid/cards", $card);
    }

    method update_card {
      my %args = @_;
      my $cid  = delete $args{customer_id};
      my $card_id = delete $args{card_id};
      return $self->_post("customers/$cid/cards/$card_id", \%args);
    }

    method delete_card {
      my %args = @_;
      my $cid  = delete $args{customer_id};
      my $card_id = delete $args{card_id};
      return $self->_delete("customers/$cid/cards/$card_id");
    }
}




=head2 Subscriptions

All methods accept the same arguments as described in the API.

See https://stripe.com/docs/api for full details.

=head3 post_subscription( PARAMHASH )

=head3 get_subscription( customer_id => CUSTOMER_ID )

=head3 delete_subscription( customer_id => CUSTOMER_ID )

=cut

Subscriptions: {
    method get_subscription {
        my %args = @_;
        my $cid = delete $args{customer_id};
        return $self->_get("customers/$cid/subscription");
    }

    # adds a subscription, keeping any existing subscriptions unmodified
    method post_subscription {
        my %args = @_;
        my $cid = delete $args{customer_id};
        my $subs = Net::Stripe::Subscription->new(%args);
        return $self->_post("customers/$cid/subscriptions", $subs);
    }
    
    method update_subscription {
      my %args = @_;
      my $cid  = delete $args{customer_id};
      my $sid  = delete $args{subscription_id};
      return $self->_post("customers/$cid/subscriptions/$sid", \%args);
    }

    method delete_subscription {
      my %args = @_;
      my $cid  = delete $args{customer_id};
      my $sid  = delete $args{subscription_id};
      my $query = '';
      $query .= '?at_period_end=true' if $args{at_period_end};
      return $self->_delete("customers/$cid/subscriptions/$sid$query");
    }
}

=head2 Tokens

All methods accept the same arguments as described in the API.

See https://stripe.com/docs/api for full details.

=head3 post_token( PARAMHASH )

=head3 get_token( TOKEN_ID )

=cut

Tokens: {
    method post_token {
        my $token = Net::Stripe::Token->new(@_);
        return $self->_post('tokens', $token);
    }

    method get_token {
        my $id = shift || die 'get_token() requires a token id';
        return $self->_get("tokens/$id");
    }
}

=head2 Plans

All methods accept the same arguments as described in the API.

See https://stripe.com/docs/api for full details.

=head3 post_plan( PARAMHASH )

=head3 get_plan( PLAN_ID )

=head3 delete_plan( PLAN_ID )

=head3 get_plans( PARAMHASH )

=cut

Plans: {
    method post_plan {
        my $plan = Net::Stripe::Plan->new(@_);
        return $self->_post('plans', $plan);
    }

    method get_plan {
        my $id = shift || die 'get_plan() requires a plan id';
        return $self->_get("plans/" . uri_escape($id));
    }

    method delete_plan {
        my $id = shift || die 'delete_plan() requires a plan id';
        $id = $id->id if ref($id);
        $self->_delete("plans/$id");
    }

    method get_plans {
        $self->_get_collections('plans', @_);
    }
}

=head2 Coupons

All methods accept the same arguments as described in the API.

See https://stripe.com/docs/api for full details.

=head3 post_coupon( PARAMHASH )

=head3 get_coupon( COUPON_ID )

=head3 delete_coupon( COUPON_ID )

=head3 get_coupons( PARAMHASH )

=cut

Coupons: {
    method post_coupon {
        my $coupon = Net::Stripe::Coupon->new(@_);
        return $self->_post('coupons', $coupon);
    }

    method get_coupon {
        my $id = shift || die 'get_coupon() requires a coupon id';
        return $self->_get("coupons/" . uri_escape($id));
    }

    method delete_coupon {
        my $id = shift || die 'delete_coupon() requires a coupon id';
        $id = $id->id if ref($id);
        $self->_delete("coupons/$id");
    }

    method get_coupons {
        $self->_get_collections('coupons', @_);
    }
}

=head2 Invoices

All methods accept the same arguments as described in the API.

See https://stripe.com/docs/api for full details.

=head3 post_invoice( PARAMHASH )

=head3 get_invoice( COUPON_ID )

=head3 get_upcominginvoice( COUPON_ID )

=head3 get_invoices( PARAMHASH )

=cut

Invoices: {

    method post_invoice {
        my %args = @_;
        return $self->_post("invoices", {@_});
    }

    method get_invoice {
        my $id = shift || die 'get_invoice() requires an invoice id';
        return $self->_get("invoices/$id");
    }

    method get_invoices {
        $self->_get_collections('invoices', @_);
    }

    method get_upcominginvoice {
        my $id = shift || die 'get_upcominginvoice() requires a customer id';
        return $self->_get("invoices/upcoming?customer=$id");
    }
}

=head2 InvoiceItems

All methods accept the same arguments as described in the API.

See https://stripe.com/docs/api for full details.

=head3 post_invoiceitem( PARAMHASH | OBJECT )

=head3 get_invoiceitem( INVOICEITEM_ID )

=head3 delete_invoiceitem( INVOICEITEM_ID )

=head3 get_invoiceitems( PARAMHASH )

=cut

InvoiceItems: {
    method post_invoiceitem {
        # Update from an existing object
        if (@_ == 1) {
            my $i = shift;
            my $item = $i->clone; $item->clear_currency;
            return $self->_post("invoiceitems/" . $i->id, $item);
        }

        my $invoiceitem = Net::Stripe::Invoiceitem->new(@_);
        return $self->_post('invoiceitems', $invoiceitem);
    }

    method get_invoiceitem {
        my $id = shift || die 'get_invoiceitem() requires a invoiceitem id';
        return $self->_get("invoiceitems/$id");
    }

    method delete_invoiceitem {
        my $id = shift || die 'delete_invoiceitem() requires a invoiceitem id';
        $id = $id->id if ref($id);
        $self->_delete("invoiceitems/$id");
    }

    method get_invoiceitems {
        $self->_get_collections('invoiceitems', @_);
    }
}

# Helper methods

method _get {
    my $path = shift;
    my $req = GET $self->api_base . '/' . $path;
    return $self->_make_request($req);
}

method _get_with_args {
    my $path = shift;
    my $args = shift;
    if (@$args) {
        $path .= "?" . join('&', @$args);
    }
    return $self->_get($path);
}

method _get_collections { 
    my $path = shift;
    my %args = @_;
    my @path_args;
    if (my $c = $args{count}) {
        push @path_args, "count=$c";
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

method _delete {
    my $path = shift;
    my $req = DELETE $self->api_base . '/' . $path;
    return $self->_make_request($req);
}

method _post {
    my $path = shift;
    my $obj  = shift;

    my $req = POST $self->api_base . '/' . $path, 
        ($obj ? (Content => [ref($obj) eq 'HASH' ? %$obj : $obj->form_fields]) : ());
    return $self->_make_request($req);
}

method _make_request {
    my $req = shift;
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

=head1 AUTHORS

Luke Closs

=head1 LICENSE

Net-Stripe is Copyright 2011 Prime Radiant, Inc.
Net-Stripe is distributed under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;
1;
