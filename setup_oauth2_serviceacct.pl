
use strict;

use Data::Dumper;
use File::Basename;
use JSON;

$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = sub { [ sort keys %{$_[0]} ] };


#----------------------------------------------------------------------
# Command line args
#----------------------------------------------------------------------
my $sajson = $ARGV[0];
my $scopes = $ARGV[1];
my $debug  = $ARGV[2];

my $usage =
    "USAGE: setup_oauth2_serviceacct.pl " .
    "<PATH TO SERVICE ACCT JSON> <SCOPES Comma separated>";

if( ! -e $sajson ) {
   print "\n";
   print "ERROR: Could not find Service Account JSON file - $sajson\n";
   print "$usage\n";
   exit 1;
}


if( $scopes eq "" ) {
   print "\n";
   print "ERROR: Scopes not provided\n";
   print "$usage\n";
   exit 1;
}


#----------------------------------------------------------------------
# Read in the JSON file and put into a hash ref
#----------------------------------------------------------------------
my $sah;

my $json = JSON->new->allow_nonref;

chmod 0600, "$sajson";

if( open FH, "<", $sajson ) {
   my $jstr;
   while( <FH> ) {
      $jstr .= $_;
   }
   close FH;
   
   $sah = $json->decode( $jstr );   
}
else {
   print "ERROR: Could not open Service Account JSON file - $sajson\n\n";
   exit 1;
}


print Dumper($sah), "\n" if $debug;


#----------------------------------------------------------------------
# Get the storage directory
#----------------------------------------------------------------------
my $sdir = File::Basename::dirname $sajson;

print "STORAGE DIR = $sdir\n" if $debug;


#----------------------------------------------------------------------
# Take the values from the JSON file and create individual files
# in the Storage Directory
#    client_id
#    private_key
#----------------------------------------------------------------------
foreach my $f ( "client_id", "client_email", "private_key" ) {
   my $fp = "$sdir/$f";
   
   if( open FH, ">", $fp ) {
      print FH $sah->{$f}, "\n";
      close FH;
      
      chmod 0600, $fp;
   }
   else {
      print "ERROR: Could not open '$fp' for write\n\n";
   }
}


#----------------------------------------------------------------------
# Write the scope file
# They should be comma separated when passed in
# Strip off any leading/trailing spaces
# One scope per line when writing to the file
#----------------------------------------------------------------------
if( open FH, ">", "$sdir/scope" ) {
   foreach ( split ",", $scopes ) {
      $_ =~ s/^\s+//;
      $_ =~ s/\s+$//;

      print FH "$_\n" if $_ ne "";
   }

   close FH;

   chmod 0600, "$sdir/scope";
}
else {
   print "ERROR: Could not open '$sdir/scope' for write\n\n";
}
