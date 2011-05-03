package Reporty::Controller::Root;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

Reporty::Controller::Root - Root Controller for Reporty

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 index

=cut

sub auto : Private {

    my ( $self, $c ) = @_;

    if ( $c->session->{config_done}  || $c->request->match =~ /configure/ ) {

        return 1;

    } else {
    
        $c->response->redirect("/report/configure"); 
        $c->detach;

    }

}

=head2 

The root page (/)

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->redirect( $c->uri_for('/report/query'));
}

=head2 default

Standard 404 error page

=cut

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

Catalyst developer

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
