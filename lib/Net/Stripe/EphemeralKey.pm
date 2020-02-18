package Net::Stripe::EphemeralKey;

use Moose;
use Moose::Util::TypeConstraints qw(union);
use Kavorka;

# ABSTRACT: represent a Ephemeral object from Stripe
# {
#   "id": "ephkey_1CfagV2eZvKYlo2CHwj6CcHl",
#   "object": "ephemeral_key",
#   "associated_objects": [
#     {
#       "type": "customer",
#       "id": "cus_D5mDverWigiZnj"
#     }
#   ],
#   "created": 1529617879,
#   "expires": 1529621479,
#   "livemode": false,
#   "secret": "ek_test_YWNjdF8xMDMyRDgyZVp2S1lsbzJDLFdZRFhEWldBNlJFWjVXMHVEbUZZcXJjbEY2aVJ5UXM"
# }


# Input fields
has 'customer'                   => (is => 'rw', isa => 'Maybe[Str]');

# Both input and output


# Output fields
has 'id'                   => (is => 'ro', isa => 'Maybe[Str]');
has 'object'               => (is => 'ro', isa => 'Maybe[Str]');
has 'associated_objects'    => (is => 'ro', isa => 'Maybe[ArrayRef]');
has 'created'              => (is => 'ro', isa => 'Maybe[Int]');
has 'expires'            => (is => 'ro', isa => 'Maybe[Int]');
has 'livemode'          => (is => 'ro', isa => 'Maybe[Bool]');
has 'secret'                => (is => 'ro', isa => 'Maybe[Str]');

method form_fields {
    return defined $self->customer ? {'customer' => $self->customer} : {} ;
}

__PACKAGE__->meta->make_immutable;
1;
