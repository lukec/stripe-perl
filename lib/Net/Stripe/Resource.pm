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

    for my $f (qw/card default_card/) {
        next unless $args{$f};
        next unless ref($args{$f}) eq 'HASH';
        $args{$f} = Net::Stripe::Card->new($args{$f});
    }

    if (my $s = $args{subscriptions}) {
        if (ref($s) eq 'HASH') {
            if (defined($s->{data}) && ref($s->{data}) eq 'ARRAY') {
                $s->{data} = [map { Net::Stripe::Subscription->new($_) } @{$s->{data}}];
            }
            $args{subscriptions} = Net::Stripe::SubscriptionList->new($s);
        }
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

method form_fields_for_metadata {
    my $metadata = $self->metadata();
    my @metadata = ();
    while( my($k,$v) = each(%$metadata) ) {
      push @metadata, 'metadata['.$k.']';
      push @metadata, $v;
    }
    return @metadata;
}

method fields_for {
    my $for = shift;
    return unless $self->can($for);
    my $thingy = $self->$for;
    return unless $thingy;
    return $thingy->form_fields if ref($thingy) =~ m/^Net::Stripe::/;
    return ($for => $thingy);
}

1;
