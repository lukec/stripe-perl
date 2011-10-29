package Net::Stripe;
use Moose;
use methods;
use LWP::UserAgent;
use HTTP::Request::Common qw/GET POST DELETE/;
use MIME::Base64 qw/encode_base64/;
use JSON qw/decode_json/;
use Try::Tiny;
use Net::Stripe::Card;
use Net::Stripe::Charge;
use Net::Stripe::Customer;
use Net::Stripe::Token;
use Net::Stripe::Error;

our $VERSION = '0.01';

has 'debug'       => (is => 'rw', isa => 'Bool', default => 0);
has 'api_key'     => (is => 'ro', isa => 'Str',    required   => 1);
has 'api_base'    => (is => 'ro', isa => 'Str',    lazy_build => 1);
has 'ua'          => (is => 'ro', isa => 'Object', lazy_build => 1);

Charges: {
    method post_charge {
        my %args = @_;
        my $charge = Net::Stripe::Charge->new(%args);
        return $self->_post('charges', $charge);
    }

    method get_charge {
        my $id = shift || die "A charge ID is required";;
        return $self->_get("charges/$id");
    }

    method refund_charge {
        my $id = shift || die "A charge ID is required";;
        $id = $id->id if ref($id);
        return $self->_post("charges/$id/refund");
    }

    method get_charges {
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

        return $self->_get_with_args('charges', \@path_args);
    }
}

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

    method get_customer {
        my $id = shift || 'get_customer() requires a customer id';
        return $self->_get("customers/$id");
    }

    method delete_customer {
        my $id = shift || 'delete_customer() requires a customer id';
        $id = $id->id if ref($id);
        $self->_delete("customers/$id");
    }

    method get_customers {
        my %args = @_;
        my @path_args;
        if (my $c = $args{count}) {
            push @path_args, "count=$c";
        }
        if (my $o = $args{offset}) {
            push @path_args, "offset=$o";
        }

        return $self->_get_with_args('customers', \@path_args);
    }
}

Tokens: {
    method post_token {
        my $token = Net::Stripe::Token->new(@_);
        return $self->_post('tokens', $token);
    }

    method get_token {
        my $id = shift || 'get_token() requires a token id';
        return $self->_get("tokens/$id");
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

method _delete {
    my $path = shift;
    my $req = DELETE $self->api_base . '/' . $path;
    return $self->_make_request($req);
}

method _post {
    my $path = shift;
    my $obj  = shift;

    my $req = POST $self->api_base . '/' . $path, 
        ($obj ? (Content => [$obj->form_fields]) : ());
    return $self->_make_request($req);
}

method _make_request {
    my $req = shift;
    $req->header( Authorization => 
        "Basic " . encode_base64($self->api_key . ':'));

    my $resp = $self->ua->request($req);
    if ($resp->code == 200) {
        my $hash = decode_json($resp->content);
        return hash_to_object($hash) if $hash->{object};
        if (my $data = $hash->{data}) {
            return [ map { hash_to_object($_) } @$data ];
        }
        return $hash;
    }

    my $e = try {
        my $hash = decode_json($resp->content);
        Net::Stripe::Error->new($hash->{error})
    }
    catch {
        Net::Stripe::Error->new(
            type => "Could not decode HTTP response: $_",
            message => $resp->status_line . " - " . $resp->content,
        );
    };

    warn "$e\n" if $self->debug;
    die $e;
}


sub hash_to_object {
    my $hash = shift;
    my $class = 'Net::Stripe::' . ucfirst($hash->{object});
    return $class->new($hash);
}

method _build_api_base { 'https://api.stripe.com/v1' }

method _build_ua {
    my $ua = LWP::UserAgent->new;
    $ua->agent("Net::Stripe/$VERSION");
    return $ua;
}


__PACKAGE__->meta->make_immutable;
1;
