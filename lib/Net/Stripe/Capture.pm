package Net::Stripe::Capture;

use Moose;
use Kavorka;
extends 'Net::Stripe::Resource';

# ABSTRACT: represent an Charge object from Stripe

has 'id'       => ( is => 'ro', isa => 'Maybe[Str]' );
has 'created'  => ( is => 'ro', isa => 'Maybe[Int]' );
has 'amount'   => ( is => 'ro', isa => 'Maybe[Int]', required => 1 );
has 'currency' => ( is => 'ro', isa => 'Maybe[Str]' );
has 'customer' => ( is => 'ro', isa => 'Maybe[Str]' );
has 'card' =>
    ( is => 'ro', isa => 'Maybe[Net::Stripe::Token|Net::Stripe::Card|Str]' );
has 'description'          => ( is => 'ro', isa => 'Maybe[Str]' );
has 'livemode'             => ( is => 'ro', isa => 'Maybe[Bool|Object]' );
has 'paid'                 => ( is => 'ro', isa => 'Maybe[Bool|Object]' );
has 'refunded'             => ( is => 'ro', isa => 'Maybe[Bool|Object]' );
has 'amount_refunded'      => ( is => 'ro', isa => 'Maybe[Int]' );
has 'captured'             => ( is => 'ro', isa => 'Maybe[Bool|Object]' );
has 'balance_transaction'  => ( is => 'ro', isa => 'Maybe[Str]' );
has 'failure_message'      => ( is => 'ro', isa => 'Maybe[Str]' );
has 'failure_code'         => ( is => 'ro', isa => 'Maybe[Str]' );
has 'application_fee'      => ( is => 'ro', isa => 'Maybe[Int]' );
has 'metadata'             => ( is => 'rw', isa => 'Maybe[HashRef]' );
has 'invoice'              => ( is => 'ro', isa => 'Maybe[Str]' );
has 'receipt_email'        => ( is => 'ro', isa => 'Maybe[Str]' );
has 'statement_descriptor' => ( is => 'ro', isa => 'Maybe[Str]' );

method form_fields {
    return ( map { $_ => $self->$_ }
            grep { defined $self->$_ }
            qw/amount application_fee receipt_email statement_descriptor/ );
}

__PACKAGE__->meta->make_immutable;
1;
