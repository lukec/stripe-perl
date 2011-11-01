package Net::Stripe::Resource;
use Moose;
use methods;

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
    if (my $s = $args{subscription}) {
        if (ref($s) eq 'HASH') {
            $args{subscription} = Net::Stripe::Subscription->new($s);
        }
    }
    if (my $p = $args{plan}) {
        if (ref($p) eq 'HASH') {
            $args{plan} = Net::Stripe::Plan->new($p);
        }
    }

    $class->$orig(%args);
};

method fields_for {
    my $for = shift;
    return unless $self->can($for);
    my $thingy = $self->$for;
    return unless $thingy;
    return $thingy->form_fields if ref($thingy) =~ m/^Net::Stripe::/;
    return ($for => $thingy);
}

1;
