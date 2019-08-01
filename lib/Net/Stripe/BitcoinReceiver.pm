package Net::Stripe::BitcoinReceiver;

use Moose;
use Kavorka;
extends 'Net::Stripe::Resource';

# ABSTRACT: represent a Bitcoin Receiver object from Stripe

# Args for creating a Receiver
has 'amount'   => ( is => 'ro', isa => 'Int', required => 1 );
has 'currency' => ( is => 'ro', isa => 'Str', required => 1 );
has 'email'    => ( is => 'ro', isa => 'Str', required => 1 );
has 'description'        => ( is => 'ro', isa => 'Maybe[Str]' );
has 'metadata'           => ( is => 'rw', isa => 'Maybe[HashRef]' );
has 'refund_mispayments' => ( is => 'ro', isa => 'Maybe[Bool]' );

# Args returned by the API
has 'id'                      => ( is => 'ro', isa => 'Maybe[Str]' );
has 'created'                 => ( is => 'ro', isa => 'Maybe[Int]' );
has 'livemode'                => ( is => 'ro', isa => 'Maybe[Bool|Object]' );
has 'active'                  => ( is => 'ro', isa => 'Maybe[Bool|Object]' );
has 'amount_received'         => ( is => 'ro', isa => 'Maybe[Int]' );
has 'bitcoin_amount'          => ( is => 'ro', isa => 'Maybe[Int]' );
has 'bitcoin_amount_received' => ( is => 'ro', isa => 'Maybe[Int]' );
has 'bitcoin_uri'             => ( is => 'ro', isa => 'Maybe[Str]' );
has 'filled'                  => ( is => 'ro', isa => 'Maybe[Bool|Object]' );
has 'inbound_address'         => ( is => 'ro', isa => 'Maybe[Str]' );
has 'uncaptured_funds'        => ( is => 'ro', isa => 'Maybe[Bool|Object]' );
has 'refund_address'          => ( is => 'ro', isa => 'Maybe[Str]' );
has 'used_for_payment'        => ( is => 'ro', isa => 'Maybe[Bool|Object]' );
has 'customer'                => ( is => 'ro', isa => 'Maybe[Str]' );
has 'payment'                 => ( is => 'ro', isa => 'Maybe[Str]' );
has 'transactions' => ( is => 'ro', isa => 'Maybe[Net::Stripe::List]' );

method form_fields () {
    return ( $self->form_fields_for_metadata(),
        map { $_ => $self->$_ }
        grep { defined $self->$_ } qw/amount currency email description refund_mispayments/ );
}

__PACKAGE__->meta->make_immutable;
1;
