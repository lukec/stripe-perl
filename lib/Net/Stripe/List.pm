package Net::Stripe::List;

use Moose;
use Kavorka;

# ABSTRACT: represent a list of objects from Stripe

has 'count'    => (is => 'ro', isa => 'Maybe[Int]'); # no longer included by default, see note below
has 'url'      => (is => 'ro', isa => 'Str', required => 1);
has 'has_more' => (is => 'ro', isa => 'Bool|Object', required => 1);
has 'data'     => (traits => ['Array'],
                   is => 'ro',
                   isa => 'ArrayRef',
                   required => 1,
                   handles => {
                       elements => 'elements',
                       map => 'map',
                       grep => 'grep',
                       first => 'first',
                       get => 'get',
                       join => 'join',
                       is_empty => 'is_empty',
                       sort => 'sort',
                   });

method last {
    return $self->get(scalar($self->elements)-1);
}

__PACKAGE__->meta->make_immutable;
1;

