package Net::Stripe::Card;
use Moose;
use methods;

# Input fields
has 'number'          => (is => 'ro', isa => 'Str');
has 'cvc'             => (is => 'ro', isa => 'Int');
has 'name'            => (is => 'ro', isa => 'Str');
has 'address_line1'   => (is => 'ro', isa => 'Str');
has 'address_line2'   => (is => 'ro', isa => 'Str');
has 'address_zip'     => (is => 'ro', isa => 'Str');
has 'address_state'   => (is => 'ro', isa => 'Str');
has 'address_country' => (is => 'ro', isa => 'Str');

# Both input and output
has 'exp_month'       => (is => 'ro', isa => 'Int', required => 1);
has 'exp_year'        => (is => 'ro', isa => 'Int', required => 1);

# Output fields
has 'country'         => (is => 'ro', isa => 'Str');
has 'cvc_check'       => (is => 'ro', isa => 'Str');
has 'last4'           => (is => 'ro', isa => 'Str');
has 'type'            => (is => 'ro', isa => 'Str');

method form_fields {
    my $meta = $self->meta;
    return (
        map { ("card[$_]" => $self->$_) }
            grep { defined $self->$_ }
                qw/number cvc name address_line1 address_line2 address_zip
                   address_state address_country exp_month exp_year/
    );
}

__PACKAGE__->meta->make_immutable;
1;
