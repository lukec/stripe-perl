package Net::Stripe::Invoiceitem;
use Moose;
use methods;
extends 'Net::Stripe::Resource';

has 'id'                => (is => 'ro', isa => 'Str');
has 'customer'          => (is => 'ro', isa => 'Str', required => 1);
has 'amount'            => (is => 'rw', isa => 'Int', required => 1);
has 'currency'          => (is => 'rw', isa => 'Str', required => 1);
has 'description'       => (is => 'rw', isa => 'Str');
has 'date'              => (is => 'ro', isa => 'Int');

method form_fields {
    return (
        map { $_ => $self->$_ }
            grep { defined $self->$_ }
                qw/amount currency description/,
                ($self->id ? () : qw/customer/)
    );
}

=head1 NAME

Net::Stripe::Invoiceitem

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
