#======================================================================
#
# NAME:  GoogleAPI::Setup.pm
#
# DESC:  Google Drive
#        Module to help with initial OAuth2 token creation
#
#        
#
# ARGS:  
#
# RET:   
#
# HIST:  
#
#======================================================================
# Copyright 2019 - Technology Resource Group LLC as an unpublished work
#======================================================================
package GoogleAPI::Setup;

use strict;

use Data::Dumper;
use File::Basename;
use HTTP::Request::Common qw(GET POST PUT);
use JSON;
use LWP::UserAgent;
use MIME::Base64;
use Time::Local;
use URI::Escape;




sub get_code_url {
   my ($sdir, $client_id, $redirect_uri, $scope) = @_;
   
   my $func = "GoogleAPI::Setup::get_code_url";
   
   # Check the storage dir
   if( ! -d $sdir ) {
      print STDERR "$func: Problem with storage dir - '$sdir'\n";
      return undef;
   }


   # Check the client ID
   if( $client_id eq "" ) {
      print STDERR "$func: Client ID not provided\n";
      return undef;
   }

   if( ! open FH, ">", "$sdir/client_id" ) {
      print STDERR "$func: Problem writing '$sdir/client_id'\n";
      return undef;
   }

   print FH "$client_id\n";
   close FH;
  

   # Check the redirect URI
   if( $redirect_uri eq "" ) {
      print STDERR "$func: Redirect URI not provided\n";
      return undef;
   }

   if( ! open FH, ">", "$sdir/redirect_uri" ) {
      print STDERR "$func: Problem writing '$sdir/redirect_uri'\n";
      return undef;
   }

   print FH "$redirect_uri\n";
   close FH;


   # Check the scope
   if( $scope eq "" ) {
      print STDERR "$func: Scope not provided\n";
      return undef;
   }

   if( ! open FH, ">", "$sdir/scope" ) {
      print STDERR "$func: Problem writing '$sdir/scope'\n";
      return undef;
   }

   print FH "$scope\n";
   close FH;

   

   my $g = GoogleAPI->new( { storage_dir => $sdir } );
   
   $g->{debug} = 1;
   
   if( ! $g ) {
      print STDERR "$func: Problem getting GoogleAPI object\n";
      return undef;
   }
   
   my $loc = $g->oauth2_get_code_url();

   if( $loc eq "" ) {
      $g->dump_error(); 
      print STDERR "$func: Empty value returned in 'Location'\n";
      return undef;
   }

   
   print "Copy the following URL into a web browser\n";
   print "It will authenticate your Google account and \n";
   print "redirect to  " . $g->{oauth2}->{redirect_uri} . "\n";
   print "Look for the value after the 'code=' in the query string\n";
   print "of the redirected URL and pass this value into the call\n";
   print "GoogleAPI::Setup::get_token(<CODE>, <CLIENT SECRET>); \n";
   print "Make sure to convert any escaped characters in the code\n";
   print "\n\n";
   print $loc;
   print "\n\n";
}




sub get_token {
   my ($sdir, $code, $client_secret) = @_;

   my $func = "GoogleAPI::Setup::get_token";
   
   # Check the storage dir
   if( ! -d $sdir ) {
      print STDERR "$func: Problem with storage dir - '$sdir'\n";
      return undef;
   }


   # Check the code
   if( $code eq "" ) {
      print STDERR "$func: Access Code not provided\n";
      return undef;
   }

   if( ! open FH, ">", "$sdir/code" ) {
      print STDERR "$func: Problem writing '$sdir/code'\n";
      return undef;
   }

   print FH "$code\n";
   close FH;

   # Check the client secret
   if( $client_secret eq "" ) {
      print STDERR "$func: Client Secret not provided\n";
      return undef;
   }

   if( ! open FH, ">", "$sdir/client_secret" ) {
      print STDERR "$func: Problem writing '$sdir/client_secret'\n";
      return undef;
   }

   print FH "$client_secret\n";
   close FH;
   

   my $g = GoogleAPI->new( { storage_dir => $sdir } );
   
   $g->{debug} = 1;
   
   if( ! $g ) {
      print STDERR "$func: Problem getting GoogleAPI object\n";
      return undef;
   }
   
   my @r = $g->oauth2_get_token();

   
   print "ACCESS TOKEN  = $r[0]\n";
   print "EXPIRES       = $r[1]\n";
   print "REFRESH TOKEN = $r[2]\n";
   print "\n\n";
   print "Tokens written to the storage directory:\n";
   print "'$sdir'\n";
   print "\n\n";
}





1;
