# This -*- perl -*- script makes the Makefile
# $Id: //depot/asn/Makefile.PL#5 $

use 5.004;
use ExtUtils::MakeMaker;

my @ppd;

@ppd = (
  AUTHOR    	=> 'Graham Barr <gbarr@pobox.com>',
  ABSTRACT  	=> 'Convert between perl data structures and ASN.1 encoded packets',
) if $] >= 5.00503;

WriteMakefile(
  VERSION_FROM  => 'lib/Convert/ASN1.pm',
  NAME          => 'Convert::ASN1',
  clean         => { FILES => 'y.tab.pl' },
  @ppd,
);

sub MY::postamble {

  my $ppd = $] >= 5.00503 ? 'ppd' : '';
  my $mkhtml = "../bin/mkhtml";
  my $html = '';

  if ( -x $mkhtml ) {
    $mkhtml = <<EDQ;
mkhtml :
	$mkhtml
EDQ
    $html = 'mkhtml';
  }
  else { $mkhtml = '' }

  return '' unless length($ppd.$html);

<<"EDQ";

distdir : $ppd $html

$mkhtml

run_byacc:
	\$(PERL) mkparse parser.y lib/Convert/ASN1/parser.pm

EDQ
}

