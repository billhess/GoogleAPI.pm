#======================================================================
#
# NAME:  GoogleAPI::Drive::FileList.pm
#
# DESC:  Google Drive File List
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
package GoogleAPI::Drive::FileList;

use strict;

use Data::Dumper;
use File::Basename;
use HTTP::Request::Common qw(GET POST PUT);
use JSON;
use LWP::UserAgent;
use MIME::Base64;
use Time::Local;
use URI::Escape;

use GoogleAPI::Drive::File;
use GoogleAPI::Drive::Folder;



#----------------------------------------------------------------------
#
# NAME:  new
#
# DESC:  
#
#        https://developers.google.com/drive/api/v3/reference/files/list
#
#                  { folders => [ ],
#                    files   => [ ],
#                    nextPageToken    =>  STRING,
#                    incompleteSearch => BOOLEAN }
#
#
# ARGS:  $g        GoogleAPI Object
#        $p        Parameters to pass to API
#
#
# RETN:  
#
# HIST:  
#
#----------------------------------------------------------------------
sub new {
   my ($h1, $h2, $h3) = @_;

   my $func = "GoogleAPI::Drive::FileList::new";

   my $g = undef;
   my $p = undef;

   #------------------------------------------------------------
   # class name - GoogleAPI::Drive::FileList->new();
   #------------------------------------------------------------
   if($h1 eq 'GoogleAPI::Drive::FileList') {
      $g = $h2 if ref $h2 eq 'GoogleAPI';
      $p = $h3 if ref $h3 eq 'HASH';
   }
   else {
      print STDERR 
          "$func ERROR: Invalid argument passed\n";
      return undef; 
   }
   
   if( ref $g ne "GoogleAPI" ) {
      print STDERR "$func: Bad GoogleAPI Object\n";
      return undef;
   }

   if( $g->{oauth2}->{access_token} eq "" ) {
      $g->add_error("$func: access_token not defined");
      return undef;
   }
   

   # Create empty object
   my $h = bless { folders          => [],
                   files            => [],
                   nextPageToken    => "",
                   incompleteSearch => "" },
       'GoogleAPI::Drive::FileList';


   # Fill empty object for first time
   GoogleAPI::Drive::FileList::list($h, $g, $p);

   
   return $h;
}




#----------------------------------------------------------------------
#
# NAME:  list
#
# DESC:  
#        https://developers.google.com/drive/api/v3/reference/files/list
#
#
# ARGS:  $self     GoogleAPI::Drive::FileList Object
#        $g        GoogleAPI Object
#        $p        Parameters to pass to API
#
#
# RETN:  
#
# HIST:  
#
#----------------------------------------------------------------------
sub list {
   my ($self, $g, $p) = @_;

   my $func = "GoogleAPI::Drive::FileList::list";

   if( ref $g ne "GoogleAPI" ) {
      $g->add_error("$func: Bad GoogleAPI Object");
      return 1;
   }

   if( $g->{oauth2}->{access_token} eq "" ) {
      $g->add_error("$func: access_token not defined");
      return 1;
   }
   
   
   my $uri = "https://www.googleapis.com/drive/v3/files";

   $uri = $p->{uri} if $p->{uri} ne "";
   delete $p->{uri};
   

   # Build the URL for the call
   my $url = $uri . "?" .
       qq(access_token=) . $g->{oauth2}->{access_token};
   

   foreach ( keys %$p ) {
      $url .= "&" . $_ . "=" . $p->{$_};
      
      # May find a case where we need to escape params??
      #$url .= "&" . $_ . "=" . uri_escape($p->{$_}) if $p->{$_};  
   }


   $g->add_debug("$func: URL:\n" . 
                 $url . "\n") if $g->{debug_http};

   my $req = HTTP::Request->new(GET => $url);

   $g->add_debug("$func: HTTP REQUEST:\n" . 
                 $req->as_string . "\n") if $g->{debug_http};


   my $res_json;

   my $success = 0;
   my $tries   = 0;
   
   # Allow multiple chances for success
   while(! $success && $tries < $g->{retry_max}) {
      $tries++;

      my $res = $g->{ua}->request($req);

      $g->add_debug("$func: HTTP RESPONSE:\n" . 
                    $res->as_string . "\n") if $g->{debug_http};
      
      if($res->is_success) {
         $res_json = $res->content;

         $success = 1;

         # If we had to retry, write a success msg to the error log
         if($tries > 1) {
            $g->add_error("$func: successful on try $tries");
         }
      }
      else {
         $g->add_error("$func: HTTP call failed - Exiting...");
         $g->add_error("$func: " . $res->status_line);
         $g->add_error("$func: try = $tries");

         # If we don't already have this info in the debug log
         # add it to the error log
         if(! $g->{debug_http}) {
            $g->add_error("$func: HTTP REQUEST:\n" . 
                          $req->as_string . "\n");
            $g->add_error("$func: HTTP RESPONSE:\n" . 
                          $res->as_string . "\n");
         }
         
         # Pause before trying again
         sleep $g->{retry_wait} if $tries < $g->{retry_max};
      }
   }


   # Make sure we got some JSON back
   if( $res_json eq "" ) {
      print "ERROR: Did not get JSON - Exiting...\n";
      return 1;
   }


   my $r = $g->{json}->decode($res_json);


   $self->{nextPageToken}    = $r->{nextPageToken};
   $self->{incompleteSearch} = $r->{incompleteSearch};


   foreach ( @{$r->{files}} ) {

      # Keep the Google API object with the Folder/File object
      $_->{g} = $g;

      
      # Folder
      if( $_->{mimeType} eq "application/vnd.google-apps.folder" ) {
         push @{$self->{folders}}, GoogleAPI::Drive::Folder::new($_);
      }
      # Not a Folder or File
      elsif( $_->{mimeType} eq "application/octet-stream" ) {
         ;
      }
      # Must be a File??
      else {
         push @{$self->{files}}, GoogleAPI::Drive::File::new($_);
      }
   }
}



#----------------------------------------------------------------------
#
# NAME:  list_next_page
#
# DESC:  
#        https://developers.google.com/drive/api/v3/reference/files/list
#
#
# ARGS:  $self     GoogleAPI::Drive::FileList Object
#        $g        GoogleAPI Object
#        $p        Parameters to pass to API
#
#
# RETN:  
#
# HIST:  
#
#----------------------------------------------------------------------
sub list_next_page {
   my ($self, $g, $p) = @_;

   my $rc = 0;

   if( $self->{nextPageToken} ) {
      $p->{pageToken} = $self->{nextPageToken};
      GoogleAPI::Drive::FileList::list($self, $g, $p);
      $rc = 1;
   }

   return $rc;
}



1;
