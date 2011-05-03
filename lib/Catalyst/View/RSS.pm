package Catalyst::View::RSS;

use utf8;
use strict;

use XML::Feed;

our $VERSION = '0.01';

use base 'Catalyst::View';

=head2 process

=cut

sub process {

    my ( $self, $c ) = @_;

    # Neuer Feed vom Type RSS
    my $feed = XML::Feed->new('RSS');

    # Meta-Daten 
    $feed->title( $c->stash->{meta}{title} );               # Titel
    $feed->link( $c->stash->{meta}{link}  );                # Link
    $feed->description( $c->stash->{meta}{description} );   # Beschreibung

    # Process the entries
    foreach my $entry ( @{ $c->stash->{entries} } ) {

        my $feed_entry = XML::Feed::Entry->new('RSS');

        $feed_entry->title( $entry->{title} );          # Titel
        $feed_entry->link( $entry->{link} );            # Link
        $feed_entry->summary( $entry->{summary} )   if $entry->{summary};   # Zusammenfassung
        $feed_entry->author( $entry->{author} )     if $entry->{author};    # Author
        $feed_entry->category( $entry->{category} ) if $entry->{category};  # Kategorie
        $feed_entry->issued( $entry->{date} );                              # Datum ( Datetime )

        $feed->add_entry($feed_entry);
    }

    $c->response->content_type('application/rss+xml');
    $c->response->body( $feed->as_xml );
}

1;

__END__

