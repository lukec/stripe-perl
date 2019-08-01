package Net::Stripe::BitcoinTransaction;

use Moose;
use Kavorka;
extends 'Net::Stripe::Resource';

# ABSTRACT: represent a Bitcoin Transaction object from Stripe

# Args for creating a Receiver
has 'id'             => ( is => 'ro', isa => 'Maybe[Str]' );
has 'amount'         => ( is => 'ro', isa => 'Maybe[Int]' );
has 'bitcoin_amount' => ( is => 'ro', isa => 'Maybe[Int]' );
has 'currency'       => ( is => 'ro', isa => 'Maybe[Str]' );
has 'receiver'       => ( is => 'ro', isa => 'Maybe[Str]' );

__PACKAGE__->meta->make_immutable;
1;
