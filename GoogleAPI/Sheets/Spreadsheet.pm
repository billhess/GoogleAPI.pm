#======================================================================
#
# NAME:  GoogleAPI::Sheets::Spreadsheet.pm
#
# DESC:  Google Sheets Spreadsheet
#
#        https://developers.google.com/sheets/api/
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
package GoogleAPI::Sheets::Spreadsheet;

use strict;

use GoogleAPI::Sheets::Sheet;
use GoogleAPI::Sheets::Row;
use GoogleAPI::Sheets::Cell;

use Data::Dumper;
use File::Basename;
use HTTP::Request::Common qw(GET POST PUT);
use JSON;
use LWP::UserAgent;
use MIME::Base64;
use Time::Local;
use URI::Escape;




#----------------------------------------------------------------------
#
# NAME:  new
#
# DESC:  Create the GoogleAPI::Sheets::Spreadsheet object
#        given a Google Drive File ID
#
#        https://sheets.googleapis.com/v4/spreadsheets/{spreadsheetId}
#
#
#
#
# ARGS:  $g        GoogleAPI Object
#        $fileid   Google Drive file ID for the Spreadsheet
#
#
# RETN:  
#
# HIST:  
#
#----------------------------------------------------------------------
sub new {
   my ($h1, $h2, $h3) = @_;

   my $func = "GoogleAPI::Sheets::Spreadsheet::new";

   my $g  = undef;

   #------------------------------------------------------------
   # class name - GoogleAPI::Sheets::Spreadsheet->new();
   #------------------------------------------------------------
   if($h1 eq 'GoogleAPI::Sheets::Spreadsheet') {
      $g  = $h2 if ref $h2 eq 'GoogleAPI';
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
   
   
   #------------------------------------------------------------
   # Check if the user passed the File/Spreadsheet ID
   #------------------------------------------------------------
   my $r = { };
   
   if(ref $h3 eq "") {
      $r = { spreadsheetUrl => '',
             spreadsheetId  => $h3 };             
   }

   #{ spreadsheetUrl => '',
   #  spreadsheetId  => '',


   return bless $r, "GoogleAPI::Sheets::Spreadsheet";
}




#----------------------------------------------------------------------
#
# NAME:  get
#
# DESC:  Retrieve a Google Sheets file from Google Drive
#
#        https://sheets.googleapis.com/v4/spreadsheets/{spreadsheetId}
#
#
#
#
# ARGS:  h1 - self
#        h2 - GoogleAPI Object
#        h3 - ID of Sheet file
#        h4 - Parameters to pass to API
#
#
# RETN:  
#
# HIST:  
#
#----------------------------------------------------------------------
sub get {
   my ($h1, $h2, $h3, $h4) = @_;

   my $func = "GoogleAPI::Sheets::Spreadsheet::get";

   my $g  = undef;
   my $id = "";
   my $p  = undef;

   #------------------------------------------------------------
   # class name - GoogleAPI::Sheets::Spreadsheet->new();
   #------------------------------------------------------------
   if( $h1 eq 'GoogleAPI::Sheets::Spreadsheet' ) {
      $g  = $h2 if ref $h2 eq 'GoogleAPI';
      $id = $h3;
      $p  = $h4 if ref $h4 eq 'HASH';
   }
   else {
      print STDERR "$func: ERROR: Invalid argument passed\n";
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
   

   # https://sheets.googleapis.com/v4/spreadsheets/{spreadsheetId}
   my $uri = "https://sheets.googleapis.com/v4/spreadsheets/";
   $uri = $p->{uri} if $p->{uri} ne "";
   delete $p->{uri};

   $uri .= $id;
   

   my $url = $uri . "?" .
       qq(access_token=) . $g->{oauth2}->{access_token} . "&" .
       qq(alt=json);
   
   
   foreach ( keys %$p ) {
      $url .= "&" . $_ . "=" . $p->{$_};
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
      $g->add_error("$func: Did not get JSON - Exiting...");
      return 1;
   }
   

   my $ss = undef;
   my $r  = $g->{json}->decode($res_json);

   if($r) {
      $ss = bless $r, "GoogleAPI::Sheets::Spreadsheet";
      
      $ss->recursive_bless();
   }

   
   return $ss;
}





#----------------------------------------------------------------------
#
# NAME:  get_unblessed
#
# DESC:  Retrieve a Google Sheets file from Google Drive
#
#        https://sheets.googleapis.com/v4/spreadsheets/{spreadsheetId}
#
#        Do not bless data.  Used for Dev purposes.
#
#
# ARGS:  h1 - self
#        h2 - GoogleAPI Object
#        h3 - ID of Sheet file
#        h4 - Parameters to pass to API
#
#
# RETN:  
#
# HIST:  
#
#----------------------------------------------------------------------
sub get_unblessed {
   my ($h1, $h2, $h3, $h4) = @_;

   my $func = "GoogleAPI::Sheets::Spreadsheet::get";

   my $g  = undef;
   my $id = "";
   my $p  = undef;

   #------------------------------------------------------------
   # class name - GoogleAPI::Sheets::Spreadsheet->new();
   #------------------------------------------------------------
   if( $h1 eq 'GoogleAPI::Sheets::Spreadsheet' ) {
      $g  = $h2 if ref $h2 eq 'GoogleAPI';
      $id = $h3;
      $p  = $h4 if ref $h4 eq 'HASH';
   }
   else {
      print STDERR 
          "$func: ERROR: Invalid argument passed\n";
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
   

   # https://sheets.googleapis.com/v4/spreadsheets/{spreadsheetId}
   my $uri = "https://sheets.googleapis.com/v4/spreadsheets/";
   $uri = $p->{uri} if $p->{uri} ne "";
   delete $p->{uri};

   $uri .= $id;
   

   my $url = $uri . "?" .
       qq(access_token=) . $g->{oauth2}->{access_token} . "&" .
       qq(alt=json);
   
   
   foreach ( keys %$p ) {
      $url .= "&" . $_ . "=" . $p->{$_};
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
   

   if( $res_json eq "" ) {
      $g->add_error("$func: Did not get JSON - Exiting...");
      return 1;
   }


   return $g->{json}->decode($res_json);
}





#----------------------------------------------------------------------
#
# NAME:  get_sheet
#
# DESC:  Get a GoogleAPI::Sheets::Sheet object for a specific sheet in
#        a Spreadsheet
#
# ARGS:  self - GoogleAPI::Sheets::Spreadsheet object
#        g    - GoogleAPI object
#        n    - sheet number (starting at zero)
#
#
# RETN:  GoogleAPI::Sheets::Sheet
#
# HIST:  031119  Created
#
#----------------------------------------------------------------------
sub get_sheet {
   my ($self, $g, $n) = @_;

   my $func = "GoogleAPI::Sheets::Spreadsheet::get_sheet";

   # Spreadsheet object expected
   if(ref $self ne "GoogleAPI::Sheets::Spreadsheet") {
      return undef
   }
   # No sheet nunber specified
   elsif($n eq '') {
      $g->add_error("$func: ERROR: Sheet number is required");
      return undef;
   }
   # Non-whole number sheet requested
   elsif($n !~ /^\d+$/) {
      $g->add_error("$func: ERROR: Invalid sheet number '$n'");
      return undef;
   }
   # No 'sheets' hash key in Spreadsheet object
   elsif(! exists $self->{sheets}) {
      return undef;
   }
   # Sheet number is too high
   elsif(($n + 1) > (scalar @{$self->{sheets}})) {
      return undef;
   }

   
   if( ! defined $self->{sheets}->[$n] ) {
      $self->{sheets}->[$n] = GoogleAPI::Sheets::Sheet->new();
   }
   elsif(ref $self->{sheets}->[$n] ne "GoogleAPI::Sheets::Sheet") {
      $self->{sheets}->[$n] =
          bless $self->{sheets}->[$n], "GoogleAPI::Sheets::Sheet";
   }

   return $self->{sheets}->[$n];
}




#----------------------------------------------------------------------
#
# NAME:  get_all_sheets
#
# DESC:  Get an array of GoogleAPI::Sheets::Sheet objects which are the
#        sheets in a Spreadsheet
#
# ARGS:  self - GoogleAPI::Sheets::Spreadsheet object
#
# RETN:  array of GoogleAPI::Sheets::Sheet
#
# HIST:  041019  Created
#
#----------------------------------------------------------------------
sub get_all_sheets {
   my ($self) = @_;

   my $func = "GoogleAPI::Sheets::Spreadsheet::get_all_sheets";

   # Spreadsheet object expected
   if(ref $self ne "GoogleAPI::Sheets::Spreadsheet") {
      return undef
   }
   # No 'sheets' hash key in Spreadsheet object
   elsif(! exists $self->{sheets}) {
      return undef;
   }

   return $self->{sheets};
}


#----------------------------------------------------------------------
#
# NAME:  create
#
# DESC:  Create a new Sheets file in Google Drive
#
#        https://developers.google.com/sheets/api/reference/
#        rest/v4/spreadsheets/create
#
#
#
#
# ARGS:  h1 - self
#        h2 - GoogleAPI Object
#        h3 - Parameters to pass to API
#
#
# RETN:  
#
# HIST:  
#
#----------------------------------------------------------------------
sub create {
   my ($h1, $h2, $h3) = @_;

   my $func = "GoogleAPI::Sheets::Spreadsheet::create";

   my $g  = undef;
   my $id = "";
   my $p  = undef;

   #------------------------------------------------------------
   # class name - GoogleAPI::Sheets::Spreadsheet->create();
   #------------------------------------------------------------
   if( $h1 eq 'GoogleAPI::Sheets::Spreadsheet' ) {
      $g  = $h2 if ref $h2 eq 'GoogleAPI';
      $p  = $h3 if (ref $h3 eq 'HASH') ||
          (ref $h3 eq 'GoogleAPI::Sheets::Spreadsheet');
   }
   else {
      print STDERR 
          "$func: ERROR: Invalid argument passed\n";
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
   

   # https://sheets.googleapis.com/v4/spreadsheets
   my $uri = "https://sheets.googleapis.com/v4/spreadsheets";
   $uri = $p->{uri} if $p->{uri} ne "";
   delete $p->{uri};


   my $url = $uri . "?" .
       qq(access_token=) . $g->{oauth2}->{access_token} . "&" .
       qq(alt=json);
   
   
#   foreach ( keys %$p ) {
#      $url .= "&" . $_ . "=" . $p->{$_};
#   }

   $g->add_debug("$func: URL:\n" . 
                 $url . "\n") if $g->{debug_http};

   
   #------------------------------------------------------------
   # Create POST request
   #------------------------------------------------------------
   my $req = HTTP::Request->new(POST => $url);


   #------------------------------------------------------------
   # Convert incoming data to JSON
   # Update request object
   #------------------------------------------------------------
   my $content = $g->{json}->convert_blessed->encode($p);

   $req->header('Content-Length' => length $content);
   $req->content($content);
   
   #print "content = $content\n";
   #print "length = ", (length $content), "\n\n";

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
      $g->add_error("$func: Did not get JSON - Exiting...");
      return 1;
   }


   #------------------------------------------------------------
   # Convert response to Spreadsheet object
   #------------------------------------------------------------
   my $ss = undef;
   my $r = $g->{json}->decode($res_json);

   if($r) {
      $ss = bless $r, "GoogleAPI::Sheets::Spreadsheet";

      $ss->recursive_bless();
   }

   
   return $ss;
}


#----------------------------------------------------------------------
#
# NAME:  batch_update
#
# DESC:  Essentially a wrapper for batchUpdate requests
#
#        https://developers.google.com/sheets/api/reference/
#        rest/v4/spreadsheets/batchUpdate
#
#
#
#
# ARGS:  h1 - self
#        h2 - GoogleAPI Object
#        h3 - the request content (array of requests)
#
#
# RETN:  res - server response
#
# HIST:  
#
#----------------------------------------------------------------------
sub batch_update {
   my ($h1, $h2, $h3) = @_;

   my $func = "GoogleAPI::Sheets::Spreadsheet::batch_update";

   my $g  = undef;
   my $p  = undef;

   #------------------------------------------------------------
   # class name - GoogleAPI::Sheets::Spreadsheet->batch_update();
   #------------------------------------------------------------
   if( ref $h1 eq 'GoogleAPI::Sheets::Spreadsheet' ) {
      $g  = $h2 if ref $h2 eq 'GoogleAPI';
      $p  = $h3;
   }
   else {
      print STDERR 
          "$func: ERROR: Invalid argument passed\n";
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
   

   # https://sheets.googleapis.com/v4/spreadsheets/{spreadsheetId}:batchUpdate
   my $uri = "https://sheets.googleapis.com/v4/spreadsheets/" .
       $h1->{spreadsheetId} . ":batchUpdate";


   my $url = $uri . "?" .
       qq(access_token=) . $g->{oauth2}->{access_token} . "&" .
       qq(alt=json);
   
   
   $g->add_debug("$func: URL:\n" . 
                 $url . "\n") if $g->{debug_http};

   
   #------------------------------------------------------------
   # Create POST request
   #------------------------------------------------------------
   my $req = HTTP::Request->new(POST => $url);


   #------------------------------------------------------------
   # Convert incoming data to JSON
   # Update request object
   #------------------------------------------------------------
   my $body = { requests => $p };
   
   my $content = $g->{json}->convert_blessed->utf8->encode($body);

   $req->header('Content-Length' => length $content);
   #$req->header('Content-Type' => "application/json; charset=utf-8");
   $req->content($content);
   
   #print "content = $content\n";
   #print "length = ", (length $content), "\n\n";

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
      $g->add_error("ERROR: Did not get JSON - Exiting...");
      return 1;
   }


   #------------------------------------------------------------
   # Convert response to Perl hash ref
   #------------------------------------------------------------
   my $r = $g->{json}->decode($res_json);
   
   return $r;
}



#----------------------------------------------------------------------
#
# NAME:  add_sheets
#
# DESC:  Add sheets to an existing Spreadsheet
#
#        https://developers.google.com/sheets/api/reference/
#        rest/v4/spreadsheets/batchUpdate
#
#
#
#
# ARGS:  h1 - self
#        h2 - GoogleAPI Object
#        h3 - array of [title,index] pairs
#                where:  title is the name of the sheet
#                        index is its position (zero = leftmost)
#                        (title and index are both optional)
#
#                Ex.:  [ [ "Tab1", 0 ], [ "Tab2", 1 ] ]
#                Ex.:  [ [  ] ]
#
# RETN:  
#
# HIST:  041019 Created
#
#----------------------------------------------------------------------
sub add_sheets {
   my ($h1, $h2, $h3) = @_;

   my $func = "GoogleAPI::Sheets::Spreadsheet::add_sheets";

   my $self = $h1;
   
   my $g  = undef;
   my $p  = undef;

   #------------------------------------------------------------
   # class name - GoogleAPI::Sheets::Spreadsheet->add_sheets();
   #------------------------------------------------------------
   if( ref $h1 eq 'GoogleAPI::Sheets::Spreadsheet' ) {
      $g  = $h2 if ref $h2 eq 'GoogleAPI';
      $p  = $h3;
   }
   else {
      print STDERR 
          "$func: ERROR: Invalid argument passed\n";
      return undef; 
   }
   
   if( ref $g ne "GoogleAPI" ) {
      print STDERR "$func: Bad GoogleAPI Object\n";
      return undef;
   }

   if( ref $p ne "ARRAY" ) {
      $g->add_error("$func: Array of sheet specs expected");
      return undef;
   }

   if( $g->{oauth2}->{access_token} eq "" ) {
      $g->add_error("$func: access_token not defined");
      return undef;
   }
   
   my @reqs;

   for my $sh (@$p) {
      if(ref $sh ne "ARRAY") {
         $g->add_error("$func: Array of sheet specs expected");
         return undef;
      }
      else {
         my $req = { 'addSheet' => { 'properties' => { } } };
         if($sh->[0] ne '') {
            $req->{addSheet}->{properties}->{title} = $sh->[0];
         }

         if($sh->[1] ne '') {
            $req->{addSheet}->{properties}->{index} = $sh->[1];
         }

         push @reqs, $req;
      }
   }

   # Run batchUpdate on requests
   my $rc = 0;
   my $r = $self->batch_update( $g, \@reqs );

   if($r && (ref $r eq "HASH") && exists $r->{replies}) {
      if(exists $r->{replies}->[0]->{addSheet}) {
         push @{$self->{sheets}},
             GoogleAPI::Sheets::Sheet->new($r->{replies}->[0]->{addSheet});
      }
   }
   elsif($g) {
      $rc = 1;
      $g->add_error("Error occurred adding sheets");
   }
   
   return $rc;
}




#----------------------------------------------------------------------
#
# NAME:  delete_sheets
#
# DESC:  Delete sheets from an existing Spreadsheet
#
#        https://developers.google.com/sheets/api/reference/
#        rest/v4/spreadsheets/batchUpdate
#
#
#
#
# ARGS:  h1 - self
#        h2 - GoogleAPI Object
#        h3 - array of GoogleAPI::Sheets::Sheet objects
#
# RETN:  
#
# HIST:  041019  Created
#
#----------------------------------------------------------------------
sub delete_sheets {
   my ($h1, $h2, $h3) = @_;

   my $func = "GoogleAPI::Sheets::Spreadsheet::delete_sheets";

   my $self = $h1;
   
   my $g  = undef;
   my $p  = undef;

   #------------------------------------------------------------
   # class name - GoogleAPI::Sheets::Spreadsheet->delete_sheets();
   #------------------------------------------------------------
   if( ref $h1 eq 'GoogleAPI::Sheets::Spreadsheet' ) {
      $g  = $h2 if ref $h2 eq 'GoogleAPI';
      $p  = $h3;
   }
   else {
      print STDERR 
          "$func: ERROR: Invalid argument passed\n";
      return undef; 
   }
   
   if( ref $g ne "GoogleAPI" ) {
      print STDERR "$func: Bad GoogleAPI Object\n";
      return undef;
   }

   if( ref $p ne "ARRAY" ) {
      $g->add_error("$func: Array of sheet objects expected");
      return undef;
   }

   if( $g->{oauth2}->{access_token} eq "" ) {
      $g->add_error("$func: access_token not defined");
      return undef;
   }
   
   my @reqs;

   for my $sh (@$p) {
      if(ref $sh ne "GoogleAPI::Sheets::Sheet") {
         $g->add_debug("$func: Array of sheet objects expected");
         $g->add_error("$func: Array of sheet objects expected");
         return undef;
      }
      else {
         my $req = { 'deleteSheet' =>
                     { 'sheetId' => $sh->{properties}->{sheetId} } };

         push @reqs, $req;
      }
   }

   # Run batchUpdate on requests
   my $rc  = 0;
   my $res = $self->batch_update( $g, \@reqs );

   $g->add_debug("Delete result:\n" . (Dumper $res));

   if( $res &&
       (ref $res eq "HASH") &&
       exists $res->{replies} &&
       (ref $res->{replies} eq "ARRAY") ) {
      my $ok = 1;
      for my $reply (@{$res->{replies}}) {
         if((scalar keys %$reply) > 0) {
            $ok = 0;
         }
      }

      if(! $ok) {
         $rc = 1;
         $g->add_error("Error occurred deleting sheets");
      }
   }
   elsif($g) {
      $rc = 1;
      $g->add_error("Error occurred deleting sheets");
   }

   return $rc;
}




#----------------------------------------------------------------------
#
# NAME:  delete_sheets_by_title
#
# DESC:  Delete sheets by title from an existing Spreadsheet
#
#        https://developers.google.com/sheets/api/reference/
#        rest/v4/spreadsheets/batchUpdate
#
#
#
#
# ARGS:  h1 - self
#        h2 - GoogleAPI Object
#        h3 - array of sheet titles (names)
#
# RETN:  
#
# HIST:  041019  Created
#
#----------------------------------------------------------------------
sub delete_sheets_by_title {
   my ($h1, $h2, $h3) = @_;

   my $func = "GoogleAPI::Sheets::Spreadsheet::delete_sheets_by_title";

   my $self = $h1;
   
   my $g  = undef;
   my $p  = undef;

   #------------------------------------------------------------
   # class name - GoogleAPI::Sheets::Spreadsheet->delete_sheets_by_title();
   #------------------------------------------------------------
   if( ref $h1 eq 'GoogleAPI::Sheets::Spreadsheet' ) {
      $g  = $h2 if ref $h2 eq 'GoogleAPI';
      $p  = $h3;
   }
   else {
      print STDERR 
          "$func: ERROR: Invalid argument passed\n";
      return undef; 
   }
   
   if( ref $g ne "GoogleAPI" ) {
      $g->add_error("$func: Bad GoogleAPI Object");
      return undef;
   }

   if( ref $p ne "ARRAY" ) {
      $g->add_error("$func: Array of sheet titles expected");
      return undef;
   }

   if( $g->{oauth2}->{access_token} eq "" ) {
      $g->add_error("$func: access_token not defined");
      return undef;
   }
   
   my @reqs;

   for my $title (@$p) {
      if(ref $title ne "") {
         $g->add_error("$func: Array of sheet titles expected");
         return undef;
      }
      else {
         for my $sh (@{$self->get_all_sheets()}) {
            $g->add_debug("SHEET =\n" . (Dumper $sh)) if $g->{debug};
            if($sh->{properties}->{title} eq $title) {
               my $req = { 'deleteSheet' =>
                           { 'sheetId' => $sh->{properties}->{sheetId} } };

               push @reqs, $req;
            }
         }
      }
   }


   # Run batchUpdate on requests
   my $r = $self->batch_update( $g, \@reqs );
   
   return $r;
}




#----------------------------------------------------------------------
#
# NAME:  recursive_bless
#
# DESC:  Bless internal Sheet, Row and Cell objects
#
# ARGS:  self - GoogleAPI::Sheets::Spreadsheet object
#
#
# RETN:  
#
# HIST:  032019  Created
#
#----------------------------------------------------------------------
sub recursive_bless {
   my ($self) = @_;

   my $func = "GoogleAPI::Sheets::Spreadsheet::recursive_bless";

   # Spreadsheet object expected
   if(ref $self eq "GoogleAPI::Sheets::Spreadsheet") {
      # Bless sheets
      for my $sheet (@{$self->{sheets}}) {
         if(ref $sheet ne "GoogleAPI::Sheets::Sheet") {
            $sheet = bless $sheet, "GoogleAPI::Sheets::Sheet"
         }
         
         # Bless rows
         next if ! exists $sheet->{data};
         for my $row (@{$sheet->{data}->[0]->{rowData}}) {
            if(ref $row ne "GoogleAPI::Sheets::Row") {
               $row = bless $row, "GoogleAPI::Sheets::Row";
            }
            
            # Bless cells
            next if ! exists $row->{values};
            for my $cell (@{$row->{values}}) {
               if(ref $cell ne "GoogleAPI::Sheets::Cell") {
                  $cell = bless $cell, "GoogleAPI::Sheets::Cell";
               }
            }
         }
      }
      
   }
}



#----------------------------------------------------------------------
#
# NAME:  update_values
#
# DESC:  Update a value in a cell or values in a range of cells on
#        an existing Sheets file
#
#        https://sheets.googleapis.com/v4/spreadsheets/{spreadsheetId}/
#               values/{range}
#
#
#
#
# ARGS:  h1 - self
#        h2 - GoogleAPI Object
#        h3 - ID of Sheet file
#        h4 - Parameters to pass to API
#             { range                        => <range>
#                  (relocate 'range' from this hash to the URL)
#               includeValuesInResponse      => <true/*false*>
#               responseDateTimeRenderOption => <SERIAL_NUMBER/
#                                                FORMATTED_STRING> 
#               responseValueRenderOption    => <FORMATTED_VALUE/
#                                                UNFORMATTED_VALUE/
#                                                FORMULA>
#               valueInputOption             => <RAW/*USER_ENTERED*>
#             }
#        h5 - data for request body
#             { values                       => <new values>
#               majorDimension               => <*ROW*/COLUMNS>
#             }
#             
# RETN:  
#
# HIST:  
#
#----------------------------------------------------------------------
sub update_values {
   my ($h1, $h2, $h3, $h4, $h5) = @_;

   my $func = "GoogleAPI::Sheets::Spreadsheet::update_values";

   my $g    = undef;
   my $id   = "";
   my $p    = { };
   my $body = { };

   #------------------------------------------------------------
   # class name - GoogleAPI::Sheets::Spreadsheet
   #------------------------------------------------------------
   if( ref $h1 eq 'GoogleAPI::Sheets::Spreadsheet' ) {
      $g    = $h2 if ref $h2 eq 'GoogleAPI';
      $id   = $h3;
      $p    = $h4 if ref $h4 eq 'HASH';
      $body = $h5 if ref $h5 eq 'HASH';
   }
   else {
      $g = $h1;
      $g->add_error("h1 = $h1");
      $g->add_error("$func: ERROR: Invalid argument passed");
      return undef; 
   }
   
   if( ref $g ne "GoogleAPI" ) {
      $g->add_error("$func: Bad GoogleAPI Object");
      return undef;
   }

   if( $g->{oauth2}->{access_token} eq "" ) {
      $g->add_error("$func: access_token not defined");
      return undef;
   }
   

   # https://sheets.googleapis.com/v4/spreadsheets/{spreadsheetId}
   #  /values/{range}
   my $uri = "https://sheets.googleapis.com/v4/spreadsheets/";
   $uri = $p->{uri} if $p->{uri} ne "";
   delete $p->{uri};

   $uri .= $id;
   

   #------------------------------------------------------------
   # Check range.  Range must be included in URI
   #------------------------------------------------------------
   if(! exists $p->{range}) {
      $g->add_error("$func: cell 'range' is required");
      return undef;
   }
   elsif($p->{range} eq '') {
      $g->add_error("$func: cell 'range' not defined");
      return undef; 
  }
   else {
      #------------------------------------------------------------
      # Range variations in "A1 notation"
      #    [<sheet_name>!][<start_cell>:]<end_cell>
      #
      #    Sheet1!C7:D10  (rectangle)
      #    Sheet1!E12     (single cell)
      #    M1:M10         (column)
      #    H6:K21         (rectangle)
      #    B1:G1          (row)
      #    J17            (single cell)
      #
      #    start_cell should be top-left
      #    end_cell should be bottom-right
      #------------------------------------------------------------
      my $range = $p->{range};
      if($range !~ /^(\w+\!)?(([a-zA-Z]+\d+\:)?([a-zA-Z]+\d+))$/) {
         $g->add_error("$func: Invalid range '$range'");
         return undef;
      }
      else {
         my $sheet      = $1;
         my $all_cells  = $2;
         my $start_cell = $3;
         my $end_cell   = $4;
         
         $uri .= "/values/" . $range;   
         delete $p->{range};

         #------------------------------------------------------------
         # See if majorDimension was set.  It can be omitted if the
         # values are in ROWS order.  But if the values are in a column,
         # then majorDimension must be set to COLUMNS.
         #------------------------------------------------------------
         if(exists $body->{majorDimension}) {
            if($body->{majorDimension} !~ /^(ROWS|COLUMNS)$/i) {
               $g->add_error("$func: majorDimension must be ROWS or COLUMNS");
               return undef;
            }
         }
         #------------------------------------------------------------
         # majorDimension was not specified.
         # See if we have multiple values in a single column
         #------------------------------------------------------------
         elsif($start_cell ne '') {
            if($start_cell =~ /^([a-zA-Z]+)(\d+)/) {
               my $c1 = uc $1;
               my $r1 = $2;
               if($end_cell =~ /^([a-zA-Z]+)(\d+)/) {
                  my $c2 = uc $1;
                  my $r2 = $2;
                  # If columns are the same but different rows...
                  if($c1 eq $c2 && $r1 != $r2) {
                     # Values are in a single column, so explicitly set
                     # majorDimension
                     $body->{majorDimension} = "COLUMNS";
                  }
               }
            }
         }
      }
   }
          
            
   my $url = $uri . "?" .
       qq(access_token=) . $g->{oauth2}->{access_token} . "&" .
       qq(alt=json);
   
   
   #------------------------------------------------------------
   # Check valueInputOption (required).
   # Default to USER_ENTERED if not specified
   #------------------------------------------------------------
   if(! exists $p->{valueInputOption}) {
      $p->{valueInputOption} = "USER_ENTERED";
   }
   elsif($p->{valueInputOption} !~ /^(USER_ENTERED|RAW)$/i) {
      $g->add_error(sprintf "$func: Invalid setting for valueInputOption '%s'",
                    $p->{valueInputOption});
      return undef;
   }

   # Add parameters to URL
   foreach ( keys %$p ) {
      $url .= "&" . $_ . "=" . $p->{$_};
   }
      
   $g->add_debug("$func: URL:\n" . 
                 $url . "\n") if $g->{debug_http};

   
   #------------------------------------------------------------
   # Create !! PUT !! request
   #------------------------------------------------------------
   my $req = HTTP::Request->new(PUT => $url);

   #------------------------------------------------------------
   # Convert incoming data to JSON.
   # Put JSON as request body.  Add JSON length to request header.
   #------------------------------------------------------------

   # "values" MUST be an array of arrays.  If we have an array of
   # scalars, enclose it with a new array
   if(ref $body->{values} eq 'ARRAY') {
      if(ref $body->{values}->[0] eq '') {
         $body->{values} = [ $body->{values} ];
      }
   }
   
   my $content = $g->{json}->convert_blessed->encode($body);

   $req->header('Content-Length' => length $content);
   $req->content($content);
   
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
      $g->add_error("ERROR: Did not get JSON - Exiting...");
      return 1;
   }


   my $ss;
   my $r = $g->{json}->decode($res_json);

   if($r) {
      $ss = bless $r, "GoogleAPI::Sheets::Spreadsheet";

      $ss->recursive_bless();
   }

   
   return $ss;
}






#----------------------------------------------------------------------
#
# NAME:  TO_JSON
#
# DESC:  Method to remove object type (blessing).  Used by JSON::encode.
#
# ARGS:  self
#
# RETN:  hash ref
#
# HIST:  032019  Created
#
#----------------------------------------------------------------------
sub TO_JSON {
   my $self = shift;
   my $a    = {};
   for (keys %$self) {
      $a->{$_} = $self->{$_};
   }
   
   return $a;
}

   
1;
