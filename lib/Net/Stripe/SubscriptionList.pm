package Net::Stripe::SubscriptionList;
use Moose;
use methods;
extends 'Net::Stripe::Resource';

has 'object' => (is => 'ro', isa => 'Str');
has 'count'  => (is => 'ro', isa => 'Int');
has 'url'    => (is => 'ro', isa => 'Str');
has 'data'   => (is => 'ro', isa => 'ArrayRef[Net::Stripe::Subscription]');

method form_fields {
    die("Cannot transform a SubscriptionList into form fields");
}

__PACKAGE__->meta->make_immutable;
1;
