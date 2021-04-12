

use strict;

use Data::Dumper;
use GoogleAPI;
use GoogleAPI::Setup;


my $sdir = $ARGV[0];

if( ! -d $sdir ) {
   print "ERROR: Not a directory - $sdir\n\n";
   print "USAGE: setup_oauth2_tokens.pl <OAUTH2 STORE DIR> <CODE>\n";
   exit 1;
}


my $code = $ARGV[1];

if( $code eq "" ) {
   print "ERROR: Need a code\n\n";
   print "USAGE: setup_oauth2_tokens.pl <OAUTH2 STORE DIR> <CODE>\n";
   exit 1;
}


my $g = GoogleAPI->new( { storage_dir => $sdir } );

#print Dumper($g) . "\n\n";


if( $g->{oauth2}->{client_secret} eq "" ) {
   print "ERROR: Check $sdir/client_secret - Exiting\n";
   exit 1;
}

GoogleAPI::Setup::get_token($sdir,
			    $code,
			    $g->{oauth2}->{client_secret});




