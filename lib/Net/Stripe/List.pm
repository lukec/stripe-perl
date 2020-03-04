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

method _next_page_args() {
    return (
        starting_after => $self->get(-1)->id,
    );
}

method _previous_page_args() {
    return (
        ending_before => $self->get(0)->id,
    );
}

fun _merge_lists(
    ArrayRef[Net::Stripe::List] :$lists!,
) {
    my $has_count = defined( $lists->[-1]->count );
    my $url = $lists->[-1]->url;
    my %list_args = (
        count => $has_count ? scalar( map { $_->elements } @$lists ) : undef,
        data => [ map { $_->elements } @$lists ],
        has_more => 0,
        url => $url,
    );
    return Net::Stripe::List->new( %list_args );
}

__PACKAGE__->meta->make_immutable;
1;

