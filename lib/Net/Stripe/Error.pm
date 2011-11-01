package Net::Stripe::Error;
use Moose;
with 'Throwable';
use namespace::clean -except => 'meta';

has 'type'    => (is => 'ro', isa => 'Str', required => 1);
has 'message' => (is => 'ro', isa => 'Str', required => 1);
has 'code'    => (is => 'ro', isa => 'Str');
has 'param'   => (is => 'ro', isa => 'Str');

use overload fallback => 1,
    '""' => sub {
        my $e = shift;
        my $msg = "Error: @{[$e->type]} - @{[$e->message]}";
        $msg .= " On parameter: " . $e->param if $e->param;
        $msg .= "\nCard error: " . $e->code   if $e->code;
        return $msg;
    };

=head1 NAME

Net::Stripe::Error

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
