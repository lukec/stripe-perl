package Net::Stripe::Plan;
use Moose;
use methods;
extends 'Net::Stripe::Resource';

has 'id'                => (is => 'rw', isa => 'Str', required => 1);
has 'amount'            => (is => 'ro', isa => 'Int', required => 1);
has 'currency'          => (is => 'ro', isa => 'Str', required => 1);
has 'interval'          => (is => 'rw', isa => 'Str', required => 1);
has 'name'              => (is => 'rw', isa => 'Str', required => 1);
has 'trial_period_days' => (is => 'rw', isa => 'Int');

method form_fields {
    return (
        map { $_ => $self->$_ }
            grep { defined $self->$_ }
                qw/id amount currency interval name trial_period_days/
    );
}

__PACKAGE__->meta->make_immutable;
1;
