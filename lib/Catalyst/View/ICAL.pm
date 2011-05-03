package Catalyst::View::ICAL;

use utf8;
use strict;
use warnings;

use MRO::Compat;

use Data::ICal;
use Data::ICal::Entry::Event;
use DateTime::Duration;
use DateTime::Format::ICal;

use Scalar::Util 'blessed';

use Catalyst::Exception;

our $VERSION = '0.01';

use base 'Catalyst::View';

__PACKAGE__->mk_accessors(
    qw[
      myconf
      ]
);

=head2 new

=cut

sub new {

    my ( $class, $c, $args ) = @_;

    my $self = $class->maybe::next::method();

    my $config = $c->config->{'View::ICAL'};

    $self->myconf("sample");

    return $self;
}

=head2 process

=cut

sub process {

    my ( $self, $c ) = @_;

    my $ical = Data::ICal->new;

    $ical->add_properties(
        'X-WR-CALNAME' => $c->stash->{title},
    );

    # Process the entries
    foreach my $entry ( @{ $c->stash->{entries} } ) {

        # Neues Event-Objekt
        my $event = Data::ICal::Entry::Event->new;

        my $start    = DateTime::Format::ICal->format_datetime( $entry->{dtstart} );
        my $end      = DateTime::Format::ICal->format_datetime( $entry->{dtend} );
        my $created  = DateTime::Format::ICal->format_datetime( $entry->{'createdate'} ) if ( $entry->{createdate} );
        my $modified = DateTime::Format::ICal->format_datetime( $entry->{'last-modified'} ) if ( $entry->{'last-modified'} );

        $event->add_properties( dtstart => $start );
        $event->add_properties( dtend   => $end );

        $event->add_properties( summary     => $entry->{title} );
        $event->add_properties( description => $entry->{description} );
        $event->add_properties( uid         => $entry->{uid} ) if $entry->{uid};

        $event->add_properties( class           => 'public' );
        $event->add_properties( url             => $entry->{url} ) if $entry->{url};
        $event->add_properties( priority        => $entry->{priority} ) if $entry->{priority};
        $event->add_properties( categories      => $entry->{categories} ) if $entry->{categories};
        $event->add_properties( location        => $entry->{location} ) if $entry->{location};
        $event->add_properties( 'last-modified' => $modified ) if $modified;
        $event->add_properties( 'created'       => $created ) if $created;

        $ical->add_entry($event);
    }

    $c->response->content_type('text/calendar; charset=UTF-8');
    $c->response->body( $ical->as_string );
}

1;

__END__

