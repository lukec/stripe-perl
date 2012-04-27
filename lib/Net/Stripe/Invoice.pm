package Net::Stripe::Invoice;
use Moose;
use methods;
extends 'Net::Stripe::Resource';

has 'id'            => ( is => 'ro', isa => 'Maybe[Str]' );
has 'created'       => ( is => 'ro', isa => 'Maybe[Int]' );
has 'subtotal'      => ( is => 'ro', isa => 'Maybe[Int]', required => 1 );
has 'amount_due'    => ( is => 'ro', isa => 'Maybe[Int]', required => 1 );
has 'attempt_count' => ( is => 'ro', isa => 'Maybe[Int]', required => 1 );
has 'attempted'     => ( is => 'ro', isa => 'Maybe[Bool]', required => 1 );
has 'closed'        => ( is => 'ro', isa => 'Maybe[Bool]', required => 1 );
has 'customer'      => ( is => 'ro', isa => 'Maybe[Str]', required => 1 );
has 'date'          => ( is => 'ro', isa => 'Maybe[Str]', required => 1 );
has 'lines'         => ( is => 'ro', isa => 'ArrayRef[Object]', required => 1 );
has 'paid'          => ( is => 'ro', isa => 'Maybe[Bool]', required => 1 );
has 'period_end'    => ( is => 'ro', isa => 'Maybe[Int]' );
has 'period_start'  => ( is => 'ro', isa => 'Maybe[Int]' );
has 'starting_balance' => ( is => 'ro', isa => 'Maybe[Int]' );
has 'subtotal'         => ( is => 'ro', isa => 'Maybe[Int]' );
has 'total'            => ( is => 'ro', isa => 'Maybe[Int]', required => 1 );
has 'charge'           => ( is => 'ro', isa => 'Maybe[Str]' );
has 'ending_balance'   => ( is => 'ro', isa => 'Maybe[Int]' );
has 'next_payment_attempt' => ( is => 'ro', isa => 'Maybe[Int]' );

has 'invoiceitems' =>
    (is => 'ro', isa => 'ArrayRef[Net::Stripe::Invoiceitem]');
has 'subscriptions' =>
    (is => 'ro', isa => 'ArrayRef[Net::Stripe::Subscription]');

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    my %args = @_ == 1 ? %{ $_[0] } : @_;


    my (@lines, @items, @subs);
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
    $args{subscriptions} = \@subs;
    $args{invoiceitems}  = \@items;
    $args{lines} = \@lines;
    $class->$orig(%args);
};

=head1 NAME

Net::Stripe::Invoice

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
