package Net::Stripe::Error;
use Moose;
with 'Throwable';
use namespace::clean -except => 'meta';

has 'type'    => (is => 'rw', isa => 'Str', required => 1);
has 'message' => (is => 'rw', isa => 'Str', required => 1);
has 'code'    => (is => 'rw', isa => 'Str');
has 'param'   => (is => 'rw', isa => 'Str');

__PACKAGE__->meta->make_immutable;
1;
