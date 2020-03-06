package Net::Stripe::Invoice;

use Moose;
use Kavorka;
extends 'Net::Stripe::Resource';

# ABSTRACT: represent an Invoice object from Stripe

has 'id'            => ( is => 'ro', isa => 'Maybe[Str]' );
has 'created'       => ( is => 'ro', isa => 'Maybe[Int]' );
has 'subtotal'      => ( is => 'ro', isa => 'Maybe[Int]', required => 1 );
has 'amount_due'    => ( is => 'ro', isa => 'Maybe[Int]', required => 1 );
has 'attempt_count' => ( is => 'ro', isa => 'Maybe[Int]', required => 1 );
has 'attempted'     => ( is => 'ro', isa => 'Maybe[Bool|Object]', required => 1 );
has 'closed'        => ( is => 'ro', isa => 'Maybe[Bool|Object]', trigger => \&_closed_change_detector);
has 'auto_advance'  => ( is => 'ro', isa => 'Maybe[Bool]');
has 'created'       => ( is => 'ro', isa => 'Maybe[Int]' );
has 'customer'      => ( is => 'ro', isa => 'Maybe[Str]', required => 1 );
has 'date'          => ( is => 'ro', isa => 'Maybe[Str]' );
has 'lines'         => ( is => 'ro', isa => 'Net::Stripe::List', required => 1 );
has 'paid'          => ( is => 'ro', isa => 'Maybe[Bool|Object]', required => 1 );
has 'period_end'    => ( is => 'ro', isa => 'Maybe[Int]' );
has 'period_start'  => ( is => 'ro', isa => 'Maybe[Int]' );
has 'starting_balance' => ( is => 'ro', isa => 'Maybe[Int]' );
has 'subtotal'         => ( is => 'ro', isa => 'Maybe[Int]' );
has 'total'            => ( is => 'ro', isa => 'Maybe[Int]', required => 1 );
has 'charge'           => ( is => 'ro', isa => 'Maybe[Str]' );
has 'ending_balance'   => ( is => 'ro', isa => 'Maybe[Int]' );
has 'next_payment_attempt' => ( is => 'ro', isa => 'Maybe[Int]' );
has 'metadata'         => ( is => 'rw', isa => 'HashRef');
has 'description' => (is => 'rw', isa => 'Maybe[Str]');

sub _closed_change_detector {
    my ($instance, $new_value, $orig_value) = @_;
    # Strip can update invoices but only wants to see the closed flag if it has been changed.
    # Meaning if you retrieve an invoice then try to update it, and it is already closed
    # it will reject the update.
    if (!defined($orig_value) || $new_value ne $orig_value) {
        $instance->{closed_value_changed} = 1;
    }
    return;
}

method form_fields {
    return $self->form_fields_for(
        qw/description metadata auto_advance/,
        ($self->{closed_value_changed} ? qw/closed/ : ())
    );
}

__PACKAGE__->meta->make_immutable;
1;
