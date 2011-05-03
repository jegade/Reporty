package Reporty::Controller::Report;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm

=head1 NAME

Reporty::Controller::Report 

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 query


=cut

sub query : Local {

    my ( $self, $c ) = @_;

    my $query = $c->session->{query} = $c->request->params->{query};

    if ($query) {

        use DBI;
        my $dsn = sprintf( "DBI:mysql:database=%s;host=%s;port=%s", $c->session->{config_database}, $c->session->{config_host}, $c->session->{config_port} );

        eval {

            my $dbh = DBI->connect( $dsn, $c->session->{config_user}, $c->session->{config_password} );

            # Now retrieve data from the table.
            my $sth = $dbh->prepare($query);
            $sth->execute();
            $c->stash->{names}   = $sth->{'NAME'};
            $c->stash->{results} = $sth->fetchall_arrayref( );

        }  ;

        $c->stash->{error_msg} = $@ if $@;
    }

    $c->stash->{template} = 'report/query.tt2';
}

=head2 export

    Export a sql query to an excel shett

=cut

sub export : Local {

    my ( $self, $c ) = @_;

    my $query = $c->session->{query} = $c->request->params->{query};

    if ($query) {

        use DBI;
        my $dsn = sprintf( "DBI:mysql:database=%s;host=%s;port=%s", $c->session->{config_database}, $c->session->{config_host}, $c->session->{config_port} );

        eval {

            my $dbh = DBI->connect( $dsn, $c->session->{config_user}, $c->session->{config_password} );

            # Now retrieve data from the table.
            my $sth = $dbh->prepare($query);
            $sth->execute();
            $c->stash->{names}   = $sth->{'NAME'};
            $c->stash->{results} = $sth->fetchall_arrayref( );

        }  ;

        if ( $@ ) {

            $c->flash->{error_msg} = $@ if $@;
            $c->response->redirect( $c->uri_for('/report/query') ) ; 

        } else {
    
            # Excel ausgeben - Excel::Template::Plus
            $c->stash->{filename} = "query.xls";
            $c->stash->{template} = 'report/export.tt2';
            $c->forward('Reporty::View::Excel');

        }

    } else {

            $c->flash->{error_msg} = "Bitte eine Query definieren";
            $c->response->redirect( $c->uri_for('/report/query') ) ; 

    }

}

sub configure : Local {

    my ( $self, $c ) = @_;

    if ( $c->request->params->{done} ) {

        my $host     = $c->session->{config_host}     = $c->request->params->{host}     || 'localhost';
        my $port     = $c->session->{config_port}     = $c->request->params->{port}     || 3306;
        my $user     = $c->session->{config_user}     = $c->request->params->{user}     || 'root';
        my $database = $c->session->{config_database} = $c->request->params->{database} || 'nacworld';
        my $password = $c->session->{config_password} = $c->request->params->{password} || '';

        my $done = $c->session->{config_done} = $c->request->params->{done} || 0;
    }
    i

      $c->stash->{template} = 'report/configure.tt2';

}

=head2 end

Attempt to render a view, if needed.

=cut

=head1 AUTHOR

Catalyst developer

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
