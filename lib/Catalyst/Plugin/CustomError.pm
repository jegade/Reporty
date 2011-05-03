package Catalyst::Plugin::CustomError;

=head1 NAME

Catalyst::Plugin::CustomError- Catalyst plugin to have more "cute" error message.

=head1 SYNOPSIS

	use Catalyst qw( CustomErrorMessage );

=head1 DESCRIPTION

You can use this module if you want to get rid of:

	(en) Please come back later
	(fr) SVP veuillez revenir plus tard
	(de) Bitte versuchen sie es spaeter nocheinmal
	(at) Konnten's bitt'schoen spaeter nochmal reinschauen
	(no) Vennligst prov igjen senere
	(dk) Venligst prov igen senere
	(pl) Prosze sprobowac pozniej

What it does is that it inherites finalize_error to $c object.

See finalize_error() function. 

=cut

use base qw{ Class::Data::Inheritable };

use HTML::Entities;
use URI::Escape qw{ uri_escape_utf8 };
use NEXT;

use strict;
use warnings;

our $VERSION = "1.00";

=head1 FUNCTIONS

=head2 finalize_error

=cut

sub finalize_error {

    my $c = shift;

    # in debug mode return the original "page"
    if ( $c->debug ) {
        $c->NEXT::finalize_error;
        return;
    }

    # create error string out of error array
    $c->stash->{error}     = join '<br/> ', map { encode_entities($_) } @{ $c->error };
    $c->stash->{template}  = 'sorry.tt2';
    $c->stash->{user}      = $c->user->obj if $c->user;
    $c->stash->{request}   = $c->request;
    $c->stash->{tracepath} = $c->session->{tracepath};

    Reporty::Com->sendmail( {
        from     => $c->technical_user,
        to       => $c->technical_user,
        subject  => $c->config->{CustomError}{subject},
        template => $c->config->{CustomError}{template},
        stash    => $c->stash,
        nodev    => 1,
        }
    );

    my $code = $c->view('TT')->render( $c, 'error.tt2', $c->stash );

    # Ausgabe encoden
    utf8::encode($code);

    # 500 Server Error
    $c->response->status(500);
    
    # Make IE happy
    $code = $code . " "x512;

    # Ausgabe
    $c->response->body($code);
    
}

1;

=head1 AUTHOR

Jens Gassmann

=head1 TODO

=head1 COPYRIGHT AND LICENSE

=cut
