package Net::Stripe::BalanceTransaction;

use Moose;
use Moose::Util::TypeConstraints qw(subtype as where message);
extends 'Net::Stripe::Resource';

# ABSTRACT: represent a BalanceTransaction object from Stripe

subtype 'TransactionType',
      as 'Str',
      where { $_ =~ /^(?:charge|refund|adjustment|application_fee(?:_refund)?|transfer_?(?:cancelfailure)?)$/ },
      message { "A transaction type must be one of charge, refund, adjustment, application_fee, application_fee_refund, transfer, transfer_cancel or transfer_failure" };

subtype 'StatusType',
  as 'Str',
  where { $_ =~ /^(?:available|pending)$/ },
  message { "A Status must be one of available or pending" };

has 'id'            => (is => 'ro', isa => 'Str');
has 'amount'        => (is => 'ro', isa => 'Int');
has 'currency'      => (is => 'ro', isa => 'Str', required => 1);
has 'net'           => (is => 'ro', isa => 'Int');
has 'type'          => (is => 'ro', isa => 'TransactionType');
has 'created'       => (is => 'ro', isa => 'Int');
has 'available_on'  => (is => 'ro', isa => 'Int');
has 'status'        => (is => 'ro', isa => 'StatusType');
has 'fee'           => (is => 'ro', isa => 'Int');
has 'fee_details'   => (is => 'ro', isa => 'Maybe[ArrayRef]');
has 'source'        => (is => 'ro', isa => 'Str');
has 'description'   => (is => 'ro', isa => 'Maybe[Str]');

__PACKAGE__->meta->make_immutable;
1;
