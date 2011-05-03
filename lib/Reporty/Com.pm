
package Reporty::Com;

use strict;
use warnings;
use utf8;

use File::MMagic;
use File::Basename;
use MIME::Lite::HTML;
use MIME::EncWords qw(:all);
use Reporty::Utils qw/config/;
use HTML::FormatText::WithLinks;
use Encode;
use Mojo::DOM;
use CSS::Inliner;

=head1 Beschreibung

Allgemeine Kommunikationschnittstellen SMS, E-Mail, Fax, usw

=cut

=head2 sendmail

    Beschreibung : Sendet eine E-Mail im kombinierten HTML/Text-Format inkl Anhänge im UTF-Format
                   HTML-Template werden automatisch als Text zusätzliche angefügt
    Einsatz      : Reporty::Com->sendmail( 
                        from          => 'Jens Gassmann <jens@atomix.de>', 
                        to            => 'Max Mustermann <muster@example.com>', 
                        cc            => 'optional',
                        subject       => 'Das ist eine Testmail',
                        template      => 'mail/template.tt2',
                        stash         => { Template => Daten }, 
                    );                        

=cut    

sub sendmail {

    my ( $self, $args ) = @_;

    my $config = Reporty::Utils->config;

    my $tt = Reporty::Utils->tt2;

    # Demo-Modus
    my $demo = ( $config->{modus} eq 'test' ) ? 1 : 0;

    die "Bitte Empfänger für den Demomodus konfigurieren" if ( $demo && !$config->{testrecipient} );

    # Prefix für den Betreff über Argumente setzen oder aus der Config ermitteln
    my $subject_prefix = "[" . ( $args->{subject_prefix} || $config->{Email}{subject_prefix} ) . "]";

    my $locale_from = $args->{from}->locale;
    my $locale_to   = $args->{to}->locale;

    # Reply-Address - Todo Kontaktstatus ermitteln
    my $reply = ( $args->{from}->privacy_email ne 'all' && !$args->{reply_ok} ) ? 'no-reply@nacworld.net' : sprintf( "%s <%s>", encode_mimeword( $args->{from}->fullname ), $args->{from}->email );

    # Offline-Benutzer nicht mehr anschreiben
    return if ( !$args->{ignorestatus} && ( $args->{to}->status eq 'locked' || $args->{to}->status eq 'deleted' ) );

    # Lokalisierung als Callback für die Sprache des Empfängers
    $args->{stash}{loc}           = sub { return Reporty::Utils->loc( $locale_to, @_ ); };
    $args->{stash}{uri_for_media} = sub { Reporty::Utils->uri_for_media(@_) };
    $args->{stash}{uri_for}       = sub { Reporty::Utils->uri_for(@_) };

    $args->{stash}{Catalyst}{loc}           = $args->{stash}{loc};
    $args->{stash}{Catalyst}{uri_for_media} = $args->{stash}{uri_for_media};
    $args->{stash}{Catalyst}{uri_for}       = $args->{stash}{uri_for};

    # Basis-CSS-Styles - hässlich aber zentral
    $args->{stash}{css_border}       = qq/style="border: 1px solid #EEE; float:  left; padding: 5px; margin: 0 5px 5px 0"/;
    $args->{stash}{css_border_right} = qq/style="border: 1px solid #EEE; float: right; padding: 5px; margin: 0 5px 5px 0"/;
    $args->{stash}{css_left_float}   = qq/style="float: left; padding: 5px; margin: 0 5px 5px 0; border: 0 none;"/;
    $args->{stash}{css_clear}        = qq/style="clear: both"/;

    # Template evaluieren
    my $html = "";
    $tt->process( $args->{template}, $args->{stash}, \$html, ) || warn $html;

    # Nachrichtenobjekt erzeugen
    my $msg = MIME::Lite->new(

        # Header nach RFC 2047 encodieren
        'From'     => $config->{Email}{from},
        'Reply-To' => $reply,
        'To'       => ($demo) ? $config->{testrecipient} : sprintf( "%s <%s>", encode_mimeword( $args->{to}->fullname, ), $args->{to}->email ),
        'Subject' => encode_mimewords( ($subject_prefix) ? $subject_prefix . ' ' . $args->{subject} : $args->{subject} ),
        'Type' => 'multipart/mixed',

        # Template-Optionen
        Charset  => 'UTF-8',
        Encoding => '8bit',
    );

    # Zusätzlicher Unsubscribe-Header
    $msg->add( 'List-Unsubscribe' => ( $args->{unsubscribe} || $config->{Email}{from} ) );
    $msg->add( 'List-ID' => $config->{Email}{from} );
    $msg->add( 'Precedence', 'list' );

    my $parser = MIME::Lite::HTML->new( IncludeType => 'cid', HTMLCharset => 'UTF-8', 'TextCharset' => 'UTF-8', 'TextEncoding' => '8bit', 'HTMLEncoding' => 'base64' );

    my $f = HTML::FormatText::WithLinks->new(
        before_link => '',
        after_link  => "\n[%l]\n",
        footnote    => '',
        base        => $config->{selfaddress},
    );

    # CSS evaluieren
    my $inliner = CSS::Inliner->new( { leave_style => 1 } );
    $inliner->read( { html => $html } );
    $html = $inliner->inlinify();

    my $phtml = encode( "utf-8", $html );

    my $plain = $f->parse($phtml);
    $plain =~ s/\[IMAGE\]//g;

    my $pplain = encode( "utf-8", $plain );

    # MIME::Part
    my $part = $parser->parse( $phtml, $pplain, $config->{selfaddress} );

    # HTML-Teil anfügen
    $msg->attach($part);

    # Attachment-Handling
    my @attachments = @{ $args->{attachments} || [] };

    if (@attachments) {

        # MimeMagic - ermitteln dem Mime-Type einer Datei
        my $mimemagic = new File::MMagic;

        # Anhänge hinzufügen
        foreach my $att (@attachments) {

            my ( $attachment, $filename ) = @$att;

            # Prüfe ob Datei vorhanden
            if ( -e $attachment ) {

                # Versuche den MIME-Type zu ermitteln
                my $mimetype = $mimemagic->checktype_filename($attachment) || 'application/octet-binary';

                $msg->attach(
                    Type        => $mimetype,
                    Path        => $attachment,
                    Filename    => $filename,
                    Disposition => 'attachment',
                );

            } else {

                warn "Konnte Anhang $attachment nicht finden";
            }
        }
    }

    # Versand via Sendmail
    $msg->send_by_sendmail( FromSender => $config->{Email}{from} );

    # Return content-part

    my $dom = Mojo::DOM->new;
    $dom->parse($html);
    my $m = $dom->at('#content')->inner_xml;
    $m =~ s/[\n\r]//g;
    return $m;

}

=head2 sms

    Beschreibung : Sendet eine SMS
    Einsatz      : Reporty::Com->sendsms( 
                        to          => '49 221 99887766', 
                        text        => 'Hallo das ist eine Testsms', 
                    );      
=cut

sub sendsms {

    my ( $self, $to, $text ) = @_;

    # TODO

    return;
}

1;
