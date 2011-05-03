package Reporty::Utils;

use strict;
use warnings;
use utf8;
use File::Slurp qw/slurp/;
use YAML qw/Load/;    # Lädt das Modul YAML und importiert die Funktion LoadFile
use Reporty::Schema;
use Template();
use Template::Stash::XS();
use Data::Dumper;
use Log::Handler();
use File::Temp();
use HTML::Entities;
use HTML::Scrubber;
use HTML::FormatText::WithLinks;
use Net::Stomp;
use Encode;
use JSON;
use Geo::IP;
use Geo::Coder::GoogleMaps;
use URI::Find::UTF8;
use URI::Escape;
use Array::Utils qw(:all);
use Digest::MD5 qw(md5 md5_hex md5_base64);

use base 'Exporter';
use vars qw/@EXPORT_OK $base_path $config $schema $tt2 $log $stomp $index $tm $es $cache/;

@EXPORT_OK = qw/base_path config schema tt2 tm/;

use File::Spec;
use Cwd qw/abs_path/;
my ( undef, $path ) = File::Spec->splitpath(__FILE__);

=head1 Beschreibung

Allgemeine Funktionen die auch ausserhalb des MVC-Webframeworks 
für Cron-Jobs/Jobserver oder Scripte gebraucht werden

=cut

=head2 base_path

    Den Basis-Pfad der Anwendung ermitteln

=cut

sub base_path {

    return $base_path if ($base_path);
    $base_path = abs_path("$path/../../");
    return $base_path;
}




=head2 config

    Die Konfiguration der Anwendung lesen

=cut

sub config {

    return $config if ($config);

    my $base_config_file = "$path/../../reporty.yml";
    my $beta_config_file = "$path/../../reporty_beta.yml";
    my $dev_config_file  = "$path/../../reporty_dev.yml";

    # Default - Produktions-Config
    if ( -e $base_config_file ) {

        # Normale Konfiguration lesen
        $config = _config_read($base_config_file);
    }

    # Prüfen ob eine Debug/Test-Konfiguration existiert
    if ( -e $dev_config_file && !-e "/etc/live" && !-e "/etc/beta" ) {

        # Lokale Konfiguration lesen
        my $extra_config = _config_read($dev_config_file);

        # Kombiniert die beiden Hash, die Extra-Konfiguration überschreibt Einträge der Basis-Konfiguratiokon
        $config = { %$config, %$extra_config };
    }

    # Prüfen ob eine Debug/Test-Konfiguration existiert
    if ( -e $beta_config_file && -e "/etc/beta" ) {

        # Lokale Konfiguration lesen
        my $extra_config = _config_read($beta_config_file);

        # Kombiniert die beiden Hash, die Extra-Konfiguration überschreibt Einträge der Basis-Konfiguratiokon
        $config = { %$config, %$extra_config };
    }

    return $config;
}

=head2 _config_read 

    Eine Config-Datei lesen, Macro-parsen und YAML in Hash konvertieren

=cut

sub _config_read {

    my ($config_file) = @_;

    # Datei einlesen
    my $yaml_config = slurp($config_file);

    # Macros ersetzen
    $yaml_config =~ s|__home__|$path/../../|gsixm;
    $yaml_config =~ s|__path_to\((.*?)\)__|$path/../../$1|gsixm;

    # YAML -> Hash
    return Load($yaml_config);
}

=head2 schema

    Datenbank-Handler, verbindet sich mit der Datenbank, aufgrund der in der config-datei vorgeben Parameter

    Rückgabe: DBIx::Class::Schema

=cut

sub schema {

    # Schema wurde schon verbunden, also globale Variable zurückgeben
    return $schema if ($schema);

    # Lese die Konfiguration, wenn diese nicht bereits gesetzt/ausgelesen ist
    $config ||= config();

    # Schema zur DB
    $schema = Reporty::Schema->connect( @{ $config->{'Model::Database'}{connect_info} } );

    # Zusätzliche Parameter setzen
    $schema->media_dir( $config->{'Model::Database'}{media_dir} );
    $schema->tmp_dir( $config->{'Model::Database'}{tmp_dir} );

    return $schema;
}

=head2 tt2

    Template-Handler, Config wird zentral ausgelesen

=cut

sub tt2 {

    return $tt2 if ($tt2);

    $config ||= config();

    $tt2 = Template->new(
        {
            %{ $config->{'View::TT'} },

            FILTERS => {
                antispam   => \&Reporty::Utils::antispam,
                html_scrub => \&Reporty::Utils::html_scrub,
                html_min   => \&Reporty::Utils::html_min,
                html_max   => \&Reporty::Utils::sanitize,
            }
        }
    );

    return $tt2;
}



=head2 dump

=cut

sub datadump {

    my ($var) = @_;
    warn Dumper($var);
}

=head2 log 

    Beschreibung: Log-Handler
    Wird global initiert

=cut

sub log {

    # Objekt besteht bereits
    return $log if $log;

    # Config laden
    $config ||= config();

    $log = Log::Handler->new;

    $log->add(
        file => {
            filename => $config->{log_dir},
            mode     => 'append',
            maxlevel => 'debug',
            minlevel => 'warn',
            newline  => 1,
        }
    );

    return $log;

}

=head2 random

    Beschreibung : Zufallstringgenerator
    Parameter    : Länge des gewünschten Strings

=cut

sub random {

    my ( $self, $length ) = @_;

    $length ||= 12;

    # Nur zeichen verwenden die man nicht verwechseln kann I <> 1 oder l <> 1
    my @chars = (qw/a b c d e f g x y z 2 3 4 5 6 8 9/);

    my $random;

    foreach ( 1 .. $length ) {
        $random .= $chars[ rand @chars ];
    }

    return $random;
}

=head2 parsedatetime

	Try to parse any given date- and timestring, time_zone is optional

=cut

sub parsedatetime {

    my ( $self, $datestring, $timestring, $time_zone ) = @_;

    my ( $day, $month, $year ) = ( $datestring =~ /^\d{4}/ ) ? reverse split( /\D/, $datestring ) : split( /\D/, $datestring );
    my ( $hour, $minute, $second ) = split( /\D/, $timestring ) if ( defined $timestring );

    my $dt;
    my $now = DateTime->now( time_zone => ( $time_zone || 'local' ) );
    my $p = {};

    $p->{day}    = $day;
    $p->{month}  = $month;
    $p->{year}   = $year;
    $p->{hour}   = $hour || $now->hour;
    $p->{minute} = $minute || $now->minute;
    $p->{second} = $second || $now->second;

    eval {

        # Try to build the DateTime-Object for the given datestring
        $dt = DateTime->new( %$p, time_zone => ( $time_zone || 'local' ) );
    };

    if ($@) {

        warn $@;
        return;
    }

    return $dt;
}

=head2

=cut

=head2 tmpfile

    Erzeugt eine temporäre Datei

=cut

sub tmpfile {

    my ( $class, $suffix ) = @_;
    my $fh = File::Temp->new( UNLINK => 0, SUFFIX => ( $suffix || '.tmp' ) );
    return $fh;
}


=head2 numiso
    
    Nummer formatieren - Internationales Format - Unicode geschütztes kurzes Leerzeichen. Ab mehr als 4 Stellen
 
    http://de.wikipedia.org/wiki/Schreibweise_von_Zahlen#ISO

=cut

sub numiso {

    my ( $self, $number ) = @_;
    $number =~ s/\D//g;
    return $number if length($number) < 5;
    my $thousand = ' ';
    while ( $number =~ s/^([-+]?\d+)(\d{3})/$1$thousand$2/s ) { 1 }

    return $number;
}

=head2 sanitize

=cut

sub sanitize {

    my $html = shift;

    my @allow = qw[ a b strong em i img br p span ul li ol li h1 h2 h3 h4 h5 blockquote div];

    my @rules = (
        script => 0,
        img    => {
            src   => 1,    # src attribute allowed
            alt   => 1,    # alt attribute allowed
            style => 1,    # style allowed
            '*'   => 0,    # deny all other attributes
        },
    );

    #
    my @default = (
        0 =>               # default rule, deny all tags
          {
            '*'           => 1,                                 # default rule, allow all attributes
            'href'        => qr{^(?!(?:java)?script)}i,
            'src'         => qr{^(?!(?:java)?script)}i,
            'cite'        => '(?i-xsm:^(?!(?:java)?script))',
            'style'       => 1,
            'language'    => 0,
            'name'        => 1,                                 # could be sneaky, but hey ;)
            'onblur'      => 0,
            'onchange'    => 0,
            'onclick'     => 0,
            'ondblclick'  => 0,
            'onerror'     => 0,
            'onfocus'     => 0,
            'onkeydown'   => 0,
            'onkeypress'  => 0,
            'onkeyup'     => 0,
            'onload'      => 0,
            'onmousedown' => 0,
            'onmousemove' => 0,
            'onmouseout'  => 0,
            'onmouseover' => 0,
            'onmouseup'   => 0,
            'onreset'     => 0,
            'onselect'    => 0,
            'onsubmit'    => 0,
            'onunload'    => 0,
            'src'         => 0,
            'type'        => 0,
          }
    );

    my $scrubber = HTML::Scrubber->new(
        allow   => \@allow,
        rules   => \@rules,
        default => \@default,
        comment => 0,
        process => 0,
    );

    return $scrubber->scrub($html);

}

=head2 radius_coordinates

    Erweitere Koordinaten auf einen Radius

=cut

sub radius_coordinates {

    my ( $self, $lon, $lat, $radius ) = @_;

    # Abstand in km pro Längengrad (Berechnung erforderlich, Annährerung - Details hier http://de.wikipedia.org/wiki/Geographische_Länge)
    my $lon_factor = cos($lat) * 2 * 3.14 * 6370 / 360;

    # Abstand in km pro Breitengrad
    my $lat_factor = 111;

    my $lon1 = $lon - ( $radius / $lon_factor );
    my $lon2 = $lon + ( $radius / $lon_factor );

    my $lat1 = $lat - ( $radius / $lat_factor );
    my $lat2 = $lat + ( $radius / $lat_factor );

    if ( $lat1 > $lat2 ) {

        ( $lat1, $lat2 ) = ( $lat2, $lat1 );
    }

    if ( $lon1 > $lon2 ) {

        ( $lon1, $lon2 ) = ( $lon2, $lon1 );
    }

    return ( $lon1, $lon2, $lat1, $lat2 );
}


=head2 html_text

=cut

sub html_text {

    my ( $self, $html ) = @_;

    my $f = HTML::FormatText::WithLinks->new(
        before_link => '',
        after_link  => ' [%l]',
        footnote    => '',
    );
    my $plain = $f->parse($html);
    $plain =~ s/\[IMAGE\]//g;
    return $plain;
}

=head2 html_min

    Allow only a minimal subset of html

=cut

sub html_min {

    my $html = shift;

    # Fix handling, of self closing tags like br/hr input
    $html =~ s|/>| />|g;    #/

    my @allow = qw[a b strong u em i span];

    my @rules = (
        script => 0,
        img    => 0,
    );

    #
    my @default = (
        0 =>                # default rule, deny all tags
          {
            '*'           => 1,                                 # default rule, allow all attributes
            'href'        => qr{^(?!(?:java)?script)}i,
            'src'         => qr{^(?!(?:java)?script)}i,
            'cite'        => '(?i-xsm:^(?!(?:java)?script))',
            'language'    => 0,
            'name'        => 1,                                 # could be sneaky, but hey ;)
            'onblur'      => 0,
            'onchange'    => 0,
            'onclick'     => 0,
            'ondblclick'  => 0,
            'onerror'     => 0,
            'onfocus'     => 0,
            'onkeydown'   => 0,
            'onkeypress'  => 0,
            'onkeyup'     => 0,
            'onload'      => 0,
            'onmousedown' => 0,
            'onmousemove' => 0,
            'onmouseout'  => 0,
            'onmouseover' => 0,
            'onmouseup'   => 0,
            'onreset'     => 0,
            'onselect'    => 0,
            'onsubmit'    => 0,
            'onunload'    => 0,
            'src'         => 0,
            'style'       => 0,
          }
    );

    my $scrubber = HTML::Scrubber->new(
        allow   => \@allow,
        rules   => \@rules,
        default => \@default,
        comment => 0,
        process => 0,
    );

    return $scrubber->scrub($html);
}

=head2 html_scrub

    Allow only a subset of html, formats, h1-h6, images and quotes

=cut

sub html_scrub {

    my $html = shift;

    # Fix handling, of self closing tags like br/hr input
    $html =~ s|/>| />|g;

    my @allow = qw[ a b strong u em i img br p span ul li ol li h1 h2 h3 h4 h5 blockquote pre];

    my @rules = (
        script => 0,
        img    => {
            src => qr{^/[^()]+$}i,    # only relative image links allowed
            alt => 1,                 # alt attribute allowed
            '*' => 0,                 # deny all other attributes
        },
    );

    #
    my @default = (
        0 =>                          # default rule, deny all tags
          {
            '*'           => 1,                                 # default rule, allow all attributes
            'href'        => qr{^(?!(?:java)?script)}i,
            'src'         => qr{^(?!(?:java)?script)}i,
            'cite'        => '(?i-xsm:^(?!(?:java)?script))',
            'language'    => 0,
            'name'        => 1,                                 # could be sneaky, but hey ;)
            'onblur'      => 0,
            'onchange'    => 0,
            'onclick'     => 0,
            'ondblclick'  => 0,
            'onerror'     => 0,
            'onfocus'     => 0,
            'onkeydown'   => 0,
            'onkeypress'  => 0,
            'onkeyup'     => 0,
            'onload'      => 0,
            'onmousedown' => 0,
            'onmousemove' => 0,
            'onmouseout'  => 0,
            'onmouseover' => 0,
            'onmouseup'   => 0,
            'onreset'     => 0,
            'onselect'    => 0,
            'onsubmit'    => 0,
            'onunload'    => 0,
            'src'         => 0,
            'style'       => 0,
          }
    );

    my $scrubber = HTML::Scrubber->new(
        allow   => \@allow,
        rules   => \@rules,
        default => \@default,
        comment => 0,
        process => 0,
    );

    return $scrubber->scrub($html);
}

=head2 html_filter

    Einfacher HTML-Filter

=cut

sub html_filter {

    my ( $self, $text ) = @_;

    for ($text) {
        s/&/&amp;/g;
        s/</&lt;/g;
        s/>/&gt;/g;
        s/"/&quot;/g;
    }

    return $text;
}

=head2 get_location_for_ip

    Ermittle Koordinaten für eine IP, über die GeoLiteCity-Datenbank

=cut

sub get_location_for_ip {

    my ( $self, $ip ) = @_;

    my $dat = $self->base_path . "/extern/GeoLiteCity.dat";

    my $gi = Geo::IP->open( $dat, GEOIP_STANDARD ) or die $! . " " . $dat;

    my $record = $gi->record_by_addr($ip);

    if ($record) {

        return ( $record->latitude, $record->longitude, 3 );

    } else {

        return ( 0, 0, 0 );
    }
}

=head2 get_location_for_address 

    Ermittle Koordinaten für eine Adresse, über Google-Maps

=cut

sub get_location_for_address {

    my ( $self, $address ) = @_;

    my $config = $self->config;

    my $gmap = Geo::Coder::GoogleMaps->new( apikey => $config->{google_maps_api_key}, output => 'xml' );

    my $response = $gmap->geocode($address);

    if ( $response->is_success ) {

        my $location = $response->placemarks->[0];
        return ( $location->latitude, $location->longitude, $location->Accuracy, $location->CountryNameCode );

    } else {

        warn $response->status->{code};
        return ( 0, 0, 0, undef );
    }
}

=head oembetify 

    Sucht jede gültige Webadresse und fügt ggf. oembed oder einen normalen Link

=cut

sub oembetify {

    my ( $self, $text, $options ) = @_;

    my $goto = sub {

        my $url = shift;
        return 'href="/goto?target=' . uri_escape($url) . '"';
    };

    # bestehende Links nicht bearbeiten
    $text =~ s|href="(.*?)"|&$goto($1)|ge;

    # Markdown-Links markieren, damit diese nicht ersetzt werden
    $text =~ s|\]\((http.*?)\)|\]\($1~~~)|g;

    my $finder = URI::Find::UTF8->new(
        sub {

            my ( $uri, $uri_string ) = @_;

            # Fertige Links nicht mehr bearbeiten
            return $uri_string if CORE::index( $uri_string, '/goto?target' ) == 0;

            # Markdown-Links nicht bearbeiten
            if ( CORE::index($uri_string, "~~~") > -1) {
                $uri_string =~ s|~~~$||g;
                return "/goto?target=". uri_escape($uri_string);
            }

            if ( $uri->scheme =~ /^http/ ) {

                # Kürze Pfad wenn mehr als 40 Zeichen lang
                my $path = decode( 'utf8', length( $uri->path ) > 40 ? encode( 'utf8', " … " ) . substr( $uri->path, -40, 40 ) : $uri->path );

                if ( $uri->host =~ /(youtube|flickr|vimeo|oohEmbed|amazon|reporty)/ ) {

                    return sprintf( qq|<a class="oembed" href="%s">%s</a>|, $uri->as_string, $uri->host . $path );

                } else {

                    return sprintf( qq|<a %s title="%s">%s</a>|, &$goto( $uri->as_string ), $uri->as_string, $uri->host . $path );

                }

            } elsif ( $uri->scheme =~ /^mailto/ ) {

                return sprintf( qq|<a href="%s">%s</a>|, $uri->as_string, $uri->as_string );

            } else {

                return $uri_string;
            }
        }
    );

    $finder->find( \$text );

    return $text;
}


sub uri_for {

    my ( $self, @args ) = @_;
    my $uri = join("/", @args);
    $uri =~ s|/+|/|g;
    return $uri;

}



=head2 uri_for_media

=cut

sub uri_for_media {

    my ( $self, $media_id, $kind ) = @_;

    my $file = $self->schema->resultset('File')->search( { media_id => $media_id, kind => $kind } )->first;

    if ( $file && -e $file->fs ) {

        if ( $self->config->{modus} ne 'test' ) {

            # mod_secdownload
            my $uri     = sprintf( "/%s/%s", $file->subdir, $media_id . "-" . $kind . "." . $file->filetype );
            my $timehex = sprintf( "%08x",   time() );
            my $md5     = md5_hex( "reporty" . $uri . $timehex );

            # URI for mod_secdownload
            return "/media/" . $md5 . "/" . $timehex . $uri;

        } else {

            # normale URL
            return $file->uri;
        }

    } else {

        # Das Media suchen
        my $media = $self->schema->resultset('Media')->find( { media_id => $media_id } );

        if ( $media && $media->type ne 'image' ) {

            return sprintf( "/static/images/dummy/%s_%s.png", ( $media->attribute->{subtype} || $media->attribute->{type} || 'dummy' ), $kind );

        } else {

            return sprintf( "/static/images/dummy/%s.png", $kind );
        }
    }
}

=head2 antispam

    Codiert alle Zeichen der E-Mailadresse in HTML-Entities um
    
    [% 'info@reporty.net' | antispam %]

=cut

sub antispam {

    my $text = shift;
    return encode_entities( $text, '\x00-\xff' );
}


1;

