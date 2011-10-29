package Net::Stripe::Resource;
use Moose;

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    my %args = @_ == 1 ? %{ $_[0] } : @_;

    # Break out the JSON::XS::Boolean values into 1/0
    for my $field (keys %args) {
        next unless ref($args{$field}) eq 'JSON::XS::Boolean';
        $args{$field} = $args{$field} ? 1 : 0;
    }

    for my $f (qw/card active_card/) {
        next unless $args{$f};
        next unless ref($args{$f}) eq 'HASH';
        $args{$f} = Net::Stripe::Card->new($args{$f});
    }

    $class->$orig(%args);
};

1;
