package Net::Stripe::Invoice;
use Moose;
use MooseX::Method::Signatures;
extends 'Net::Stripe::Resource';

# ABSTRACT: represent an Invoice object from Stripe

has 'id'            => ( is => 'ro', isa => 'Maybe[Str]' );
has 'created'       => ( is => 'ro', isa => 'Maybe[Int]' );
has 'subtotal'      => ( is => 'ro', isa => 'Maybe[Int]', required => 1 );
has 'amount_due'    => ( is => 'ro', isa => 'Maybe[Int]', required => 1 );
has 'attempt_count' => ( is => 'ro', isa => 'Maybe[Int]', required => 1 );
has 'attempted'     => ( is => 'ro', isa => 'Maybe[Bool|Object]', required => 1 );
has 'closed'        => ( is => 'ro', isa => 'Maybe[Bool|Object]', required => 1, trigger => \&_closed_change_detector);
has 'customer'      => ( is => 'ro', isa => 'Maybe[Str]', required => 1 );
has 'date'          => ( is => 'ro', isa => 'Maybe[Str]', required => 1 );
has 'lines'         => ( is => 'ro', isa => 'ArrayRef[Object]', required => 1 );
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

has 'invoiceitems' =>
    (is => 'ro', isa => 'ArrayRef[Net::Stripe::Invoiceitem]');
has 'subscriptions' =>
    (is => 'ro', isa => 'ArrayRef[Net::Stripe::Subscription]');

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
    return (
        $self->form_fields_for_metadata(),
        (($self->{closed_value_changed}) ? (closed => (($self->closed) ? 'true' : 'false')) : ()),
        map { ($_ => $self->$_) }
            grep { defined $self->$_ } qw/description/
    );
}


around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    my %args = @_ == 1 ? %{ $_[0] } : @_;


    my (@lines, @items, @subs);
    # Old style?
    for my $i (@{ $args{lines}{invoiceitems} || [] }) {
        my $item = Net::Stripe::Invoiceitem->new($i);
        push @lines, $item;
        push @items, $item;
    }
    for my $s (@{ $args{lines}{subscriptions} || [] }) {
        my $sub = Net::Stripe::Subscription->new($s);
        push @lines, $sub;
        push @subs, $sub;
    }

    # New style?
    if ($args{lines}{object} eq 'list') {
        for my $line (@{ $args{lines}{data} }) {
            if ($line->{type} eq 'invoiceitem') {
                $line->{customer} = $args{customer};
                my $item = Net::Stripe::Invoiceitem->new($line);
                push @lines, $item;
                push @items, $item;
            }
            elsif ($line->{type} eq 'subscription') {
                my $sub = Net::Stripe::Subscription->new($line);
                push @lines, $sub;
                push @subs, $sub;
            }
        }
    }


    $args{subscriptions} = \@subs;
    $args{invoiceitems}  = \@items;
    $args{lines} = \@lines;
    $class->$orig(%args);
};

__PACKAGE__->meta->make_immutable;
1;
