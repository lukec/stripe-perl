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

__PACKAGE__->meta->make_immutable;
1;
