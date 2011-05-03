package Catalyst::View::Excel::Template::Plus;

use strict;
use utf8;
use warnings;

use NEXT;
use Excel::Template::Plus;
use Scalar::Util 'blessed';

use Catalyst::Exception;

our $VERSION   = '0.03';

use base 'Catalyst::View';

__PACKAGE__->mk_accessors(
    qw[
      etp_engine
      etp_config
      etp_params
      ]
);

sub new {
    my ( $class, $c, $args ) = @_;
    my $self = $class->NEXT::new( $c, $args );

    my $config = $c->config->{'View::Excel::Template::Plus'};

    $args->{etp_engine} ||= $config->{etp_engine} || 'TT';
    $args->{etp_config} ||= $config->{etp_config} || {};
    $args->{etp_params} ||= $config->{etp_params} || {};

    $self->etp_engine( $args->{etp_engine} );
    $self->etp_config( $args->{etp_config} );
    $self->etp_params( $args->{etp_params} );

    return $self;
}

sub process {
    my $self = shift;
    my $c    = shift;
    my @args = @_;

    my $template = $self->get_template_filename($c);

    ( defined $template )
      || die 'No template specified for rendering';

    my $etp_engine = $c->stash->{etp_engine} || $self->etp_engine;
    my $etp_config = $c->stash->{etp_config} || $self->etp_config;
    my $etp_params = $c->stash->{etp_params} || $self->etp_params;

    $c->stash->{Catalyst} = $c;

    my $excel = $self->create_template_object(
        $c => (
            engine   => $etp_engine,
            template => $template,
            config   => $etp_config,
            params   => $etp_params,
        )
    );

    $excel->param( $self->get_template_params($c) );
    

    # Filename for the output
    my $filename = $c->stash->{filename} ;

    # Ouput
    my $output = $excel->output;
 
    # Header aufbereiten
    $c->response->header( 'Content-Disposition', qq[attachment; filename="$filename"] );
    $c->response->content_type('application/x-msexcel');
    $c->response->headers->content_length( length( $output ) );
    $c->response->body( $output );
}

sub create_template_object {
    my ( $self, $c, %options ) = @_;
    Excel::Template::Plus->new(%options);
}

sub get_template_filename {
    my ( $self, $c ) = @_;
    $c->stash->{template}
      || ( $c->action . '.xml.' . $self->config->{TEMPLATE_EXTENSION} );
}

sub get_template_params {
    my ( $self, $c ) = @_;
    my $cvar = $self->config->{CATALYST_VAR} || 'c';
    
    # Alle Sonderzeichen aus dem Arbeitblattnamen entfernen
    $c->stash->{worksheet} =~ s/\W/ /ig;

    # Arbeitsblattnamen auf 31 Zeichen begrenzen
    $c->stash->{worksheet} = substr( $c->stash->{worksheet}, 0, 30 );
    return ( $cvar => $c, %{ $c->stash } );
}

1;

__END__

=pod

=head1 NAME

Catalyst::View::Excel::Template::Plus - A Catalyst View for Excel::Template::Plus

=head1 SYNOPSIS

=head1 DESCRIPTION

This is a Catalyst View subclass which can handle rendering excel content
through Excel::Template::Plus. 

=head1 CONFIG OPTIONS

=over 4

=item I<etp_engine>

=item I<etp_config>

=item I<etp_params>

=back

=head1 METHODS

=over 4

=item B<new>

This really just handles consuming the configuration parameters.

=item B<process>

=item B<get_template_filename>

=item B<get_template_params>

=item B<create_template_object>

=back

=head1 BUGS

All complex software has bugs lurking in it, and this module is no 
exception. If you find a bug please either email me, or add the bug
to cpan-RT.

=head1 AUTHOR

Stevan Little E<lt>stevan.little@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2007 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
