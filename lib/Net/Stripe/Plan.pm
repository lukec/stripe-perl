package Net::Stripe::Plan;

use Moose;
use Moose::Util::TypeConstraints qw(subtype as where message);
use Kavorka;
extends 'Net::Stripe::Resource';

# ABSTRACT: represent a Plan object from Stripe

subtype 'StatementDescriptor',
    as 'Str',
    where { !defined($_) || $_ =~ /^[^<>"']{0,15}$/ },
    message { "The statement descriptor you provided '$_' must be 15 characters or less and not contain <>\"'." };

has 'id'                => (is => 'ro', isa => 'Maybe[Str]', required => 1);
has 'amount'            => (is => 'ro', isa => 'Maybe[Int]', required => 1);
has 'currency'          => (is => 'ro', isa => 'Maybe[Str]', required => 1);
has 'interval'          => (is => 'ro', isa => 'Maybe[Str]', required => 1);
has 'interval_count'    => (is => 'ro', isa => 'Maybe[Int]', required => 0);
has 'name'              => (is => 'ro', isa => 'Maybe[Str]', required => 1);
has 'trial_period_days' => (is => 'ro', isa => 'Maybe[Int]');
has 'statement_descriptor' => (is => 'ro', isa => 'Maybe[StatementDescriptor]', required => 0);

method form_fields {
    return (
        map { $_ => $self->$_ }
            grep { defined $self->$_ }
                qw/id amount currency interval interval_count name statement_descriptor trial_period_days/
    );
}

__PACKAGE__->meta->make_immutable;
1;
