package Net::Stripe::Customer;
use Moose;
use methods;
extends 'Net::Stripe::Resource';

# Customer creation args
has 'email'       => (is => 'rw', isa => 'Str');
has 'description' => (is => 'rw', isa => 'Str');
has 'trial_end'   => (is => 'rw', isa => 'Int');
has 'card'        => (is => 'rw', isa => 'Maybe[Net::Stripe::Card]');
has 'plan'        => (is => 'rw', isa => 'Maybe[Net::Stripe::Plan]');
has 'coupon'      => (is => 'rw', isa => 'Maybe[Net::Stripe::Coupon]');

# API object args
has 'id'          => (is => 'rw', isa => 'Str');
has 'deleted'     => (is => 'rw', isa => 'Bool', default => 0);
has 'active_card' => (is => 'rw', isa => 'Maybe[Net::Stripe::Card]');

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    my %p = @_ == 1 ? %{ $_[0] } : @_;
    $p{card} = Net::Stripe::Card->new($p{card}) if $p{card};
    $class->$orig(%p);
};

method form_fields {
    my $meta = $self->meta;
    return (
        ($self->card   ? $self->card->form_fields   : ()),
        ($self->plan   ? $self->plan->form_fields   : ()),
        ($self->coupon ? $self->coupon->form_fields : ()),
        map { ($_ => $self->$_) }
            grep { defined $self->$_ } qw/email description trial_end/
    );
}

__PACKAGE__->meta->make_immutable;
1;
