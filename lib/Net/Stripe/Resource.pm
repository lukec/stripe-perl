package Net::Stripe::Resource;

# ABSTRACT: represent a Resource object from Stripe

use Moose;
use Kavorka;

has 'boolean_attributes' => (is => 'ro', isa => 'ArrayRef[Str]');

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    my %args = @_ == 1 ? %{ $_[0] } : @_;

    # Break out the JSON::XS::Boolean values into 1/0
    for my $field (keys %args) {
        if (ref($args{$field}) =~ /^(JSON::XS::Boolean|JSON::PP::Boolean)$/) {
            $args{$field} = $args{$field} ? 1 : 0;
        }
    }

    for my $f (qw/card default_card/) {
        next unless $args{$f};
        next unless ref($args{$f}) eq 'HASH';
        $args{$f} = Net::Stripe::Card->new($args{$f});
    }

    if (my $s = $args{subscription}) {
        if (ref($s) eq 'HASH') {
            $args{subscription} = Net::Stripe::Subscription->new($s);
        }
    }
    if (my $s = $args{coupon}) {
        if (ref($s) eq 'HASH') {
            $args{coupon} = Net::Stripe::Coupon->new($s);
        }
    }
    if (my $s = $args{discount}) {
        if (ref($s) eq 'HASH') {
            $args{discount} = Net::Stripe::Discount->new($s);
        }
    }
    if (my $p = $args{plan}) {
        if (ref($p) eq 'HASH') {
            $args{plan} = Net::Stripe::Plan->new($p);
        }
    }

    for my $attr ($class->meta()->get_all_attributes()) {
      next if !($attr->type_constraint && (
          $attr->type_constraint eq 'Bool' ||
          $attr->type_constraint eq 'Maybe[Bool]' ||
          $attr->type_constraint eq 'Maybe[Bool|Object]'
      ));
      push @{$args{boolean_attributes}}, $attr->name;
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

method fields_for($for) {
    return unless $self->can($for);
    my $thingy = $self->$for;
    return unless $thingy;
    return $thingy->form_fields if ref($thingy) =~ m/^Net::Stripe::/;
    return ($for => $thingy);
}

method is_a_boolean(Str $attr!) {
  my %boolean_attributes = map { $_ => 1 } @{$self->boolean_attributes()};
  return exists( $boolean_attributes{$attr} );
}

method get_form_field_value(Str $attr!) {
  my $value = $self->$attr;
  return $value if ! $self->is_a_boolean( $attr );
  return ( defined( $value ) && $value ) ? 'true' : 'false';
}

1;
