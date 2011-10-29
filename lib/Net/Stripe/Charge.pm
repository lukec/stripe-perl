package Net::Stripe::Charge;
use Moose;
use methods;
extends 'Net::Stripe::Resource';

has 'id'          => (is => 'rw', isa => 'Str');
has 'created'     => (is => 'rw', isa => 'Int');
has 'fee'         => (is => 'rw', isa => 'Int');
has 'amount'      => (is => 'ro', isa => 'Int', required => 1);
has 'currency'    => (is => 'ro', isa => 'Str', required => 1);
has 'customer'    => (is => 'ro', isa => 'Str');
has 'card'        => (is => 'ro', isa => 'StripeCard');
has 'description' => (is => 'rw', isa => 'Str');
has 'livemode'    => (is => 'rw', isa => 'Bool');
has 'paid'        => (is => 'rw', isa => 'Bool');
has 'refunded'    => (is => 'rw', isa => 'Bool');

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    my %args = @_ == 1 ? %{ $_[0] } : @_;
    die "customer OR card is required"
        unless (($args{customer} or $args{card})
            and not($args{customer} and $args{card}));

    $class->$orig(%args);
};

method form_fields {
    return (
        $self->card_form_fields,
        map { $_ => $self->$_ }
            grep { defined $self->$_ }
                qw/amount currency customer description/
    );
}


__PACKAGE__->meta->make_immutable;
1;
