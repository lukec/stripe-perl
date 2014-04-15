package Net::Stripe::Plan;
use Moose;
use Moose::Util::TypeConstraints;
use methods;
extends 'Net::Stripe::Resource';

union 'StripePlan', ['Str', 'Net::Stripe::Plan'];

subtype 'StatementDescription',
    as 'Str',
    where { $_ =~ /^[^<>"']{0,15}$/ },
    message { "The statement description you provided '$_' must be 15 characters or less and not contain <>\"'." };

has 'id'                => (is => 'ro', isa => 'Maybe[Str]', required => 1);
has 'amount'            => (is => 'ro', isa => 'Maybe[Int]', required => 1);
has 'currency'          => (is => 'ro', isa => 'Maybe[Str]', required => 1);
has 'interval'          => (is => 'ro', isa => 'Maybe[Str]', required => 1);
has 'interval_count'    => (is => 'ro', isa => 'Maybe[Int]', required => 0);
has 'name'              => (is => 'ro', isa => 'Maybe[Str]', required => 1);
has 'trial_period_days' => (is => 'ro', isa => 'Maybe[Int]');
has 'statement_description' => ('is' => 'ro', isa => 'Maybe[StatementDescription]', required => 0);

method form_fields {
    return (
        map { $_ => $self->$_ }
            grep { defined $self->$_ }
                qw/id amount currency interval interval_count name statement_description trial_period_days/
    );
}

=head1 NAME

Net::Stripe::Plan

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
