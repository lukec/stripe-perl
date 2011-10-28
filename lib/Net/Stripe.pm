package Net::Stripe;
use Moose;
use methods;
use LWP::UserAgent;
use HTTP::Request::Common;
use MIME::Base64 qw/encode_base64/;
use JSON qw/decode_json/;
use Try::Tiny;
use Net::Stripe::Charge;
use Net::Stripe::Card;
use Net::Stripe::Error;

our $VERSION = '0.01';

has 'api_key'     => (is => 'ro', isa => 'Str',    required   => 1);
has 'api_base'    => (is => 'ro', isa => 'Str',    lazy_build => 1);
has 'ua'          => (is => 'ro', isa => 'Object', lazy_build => 1);

method post_charge {
    my %args = @_;
    my $charge = Net::Stripe::Charge->new(%args);
    return $self->_post('charges', $charge);
}

method get_charge {
    my $id = shift;
    return $self->_get("charges/$id");
}

method refund_charge {
    my $id = shift;
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

    my $path = "charges";
    if (@path_args) {
        $path .= "?" . join('&', @path_args);
    }
    return $self->_get($path);
}

method _get {
    my $path = shift;
    my $req = GET $self->api_base . '/' . $path;
    return $self->_make_request($req);
}

method _post {
    my $path = shift;
    my $obj  = shift;

    my $req = POST $self->api_base . '/' . $path, 
        ($obj ? (Content => $obj->form_fields) : ());
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

    die try {
        my $hash = decode_json($resp->content);
        Net::Stripe::Error->new($hash->{error})
    }
    catch {
        Net::Stripe::Error->new(
            type => "Could not decode HTTP response: $_",
            message => $resp->status_line . " - " . $resp->content,
        );
    };
    
    # Handle these cases:
    # * 200 OK
    # * 400 Bad Request - Missing a req parameter
    # * 401 Un-authorized - No valid API key
    # * 402 Request Failed - Params were valid but req failed
    # * 404 Not Found
    # * 50X - Something wrong on their end
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
