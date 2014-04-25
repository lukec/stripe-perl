package Net::Stripe::SubscriptionList;
use Moose;
use MooseX::Method::Signatures;
extends 'Net::Stripe::Resource';

# ABSTRACT: represent a list of Subscriptions from Stripe

has 'object' => (is => 'ro', isa => 'Str');
has 'count'  => (is => 'ro', isa => 'Int'); # no longer included by default, see note below
has 'url'    => (is => 'ro', isa => 'Str');
has 'data'   => (is => 'ro', isa => 'ArrayRef[Net::Stripe::Subscription]');

method form_fields {
    die("Cannot transform a SubscriptionList into form fields");
}

__PACKAGE__->meta->make_immutable;
1;

__END__
From the Stripe Change Log:
2014-03-28
Remove count property from list responses, replacing it with the optional property total_count. 
You can request that total_count be included in your responses by specifying include[]=total_count.
