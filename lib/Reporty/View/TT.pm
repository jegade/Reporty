package Reporty::View::TT;

use strict;
use base 'Catalyst::View::TT::ForceUTF8';

use Reporty::Utils;

=head1 NAME

ATOMIX::FeedReader::View::View - Catalyst TT View

=head1 SYNOPSIS

See L<ATOMIX::FeedReader>

=head1 DESCRIPTION

Catalyst TT View.

=cut


=head2 Filter laden

    Die gewünschten Filter laden    

=cut

__PACKAGE__->config->{FILTERS} = {
    antispam   => \&Reporty::Utils::antispam,
    html_scrub => \&Reporty::Utils::html_scrub,
    html_min   => \&Reporty::Utils::html_min,
    html_max   => \&Reporty::Utils::sanitize,
};


=head1 AUTHOR


=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
