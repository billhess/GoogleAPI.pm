#======================================================================
#
# NAME:  GoogleAPI::Drive::File.pm
#
# DESC:  Google Drive File
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
package GoogleAPI::Drive::File;

use strict;

use Data::Dumper;
use Data::UUID;
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
# DESC:  Create a new GoogleAPI::Drive::File object
#
# ARGS:  
#
# RETN:  blessed object
#
# HIST:  
#
#----------------------------------------------------------------------
sub new {
   my ( $f ) = @_;
   
   if( (ref $f eq "HASH") && (exists $f->{id}) ) {      
      return bless $f, 'GoogleAPI::Drive::File';
   }
   else {
      return undef;
   }
}





#----------------------------------------------------------------------
#
# NAME:  get
#
# DESC:  
#        https://developers.google.com/drive/api/v3/reference/files/get
#
#
# ARGS:  $p        Parameters to pass to API
#
#
#
# RETN:  
#
# HIST:  
#
#----------------------------------------------------------------------
sub get {
   my ($f, $p) = @_;

   my $func = "GoogleAPI::Drive::File::get";
   

   if( ref $f ne "GoogleAPI::Drive::File" ) {
      $f->{g}->add_error("$func: Incorrect object");
      return 1;
   }

   if( $f->{g}->{oauth2}->{access_token} eq "" ) {
      $f->{g}->add_error("$func: access_token not defined");
      return 1;
   }

      
   my $uri = "https://www.googleapis.com/drive/v3/files";
   $uri = $p->{uri} if $p->{uri} ne "";

   $uri .= "/" . $f->{id};

   
   my $url = $uri . "?" .
       qq(access_token=) . $f->{g}->{oauth2}->{access_token};
   
   foreach ( "acknowledgeAbuse",
             "supportsTeamDrives",
             "supportsAllDrives" ) {      
      $url .= "&" . $_ . "=" . $p->{$_} if $p->{$_};
   }


   $f->{g}->add_debug("$func: URL:\n" . 
                 $url . "\n") if $f->{g}->{debug_http};

   
   my $req = HTTP::Request->new(GET => $url);

   $f->{g}->add_debug("$func: HTTP REQUEST:\n" . 
                 $req->as_string . "\n") if $f->{g}->{debug_http};
   
   my $res_json;
   
   my $success = 0;
   my $tries   = 0;
   
   # Allow multiple chances for success
   while(! $success && $tries < $f->{g}->{retry_max}) {
      $tries++;

      my $res = $f->{g}->{ua}->request($req);
      
      $f->{g}->add_debug("$func: HTTP RESPONSE:\n" . 
                    $res->as_string . "\n") if $f->{g}->{debug_http};

   
      if($res->is_success) {
         $res_json = $res->content;

         $success = 1;

         # If we had to retry, write a success msg to the error log
         if($tries > 1) {
            $f->{g}->add_error("$func: successful on try $tries");
         }
      }
      else {
         $f->{g}->add_error("$func: HTTP call failed - Exiting...");
         $f->{g}->add_error("$func: " . $res->status_line);
         $f->{g}->add_error("$func: try = $tries");

         # If we don't already have this info in the debug log
         # add it to the error log
         if(! $f->{g}->{debug_http}) {
            $f->{g}->add_error("$func: HTTP REQUEST:\n" . 
                          $req->as_string . "\n");
            $f->{g}->add_error("$func: HTTP RESPONSE:\n" . 
                          $res->as_string . "\n");
         }
         
         # Pause before trying again
         sleep $f->{g}->{retry_wait} if $tries < $f->{g}->{retry_max};
      }
   }


   # Make sure we got some JSON back
   if( $res_json eq "" ) {
      print "$func: Did not get JSON - Exiting...\n";
      return 1;
   }


   $f->{metadata} = $f->{g}->{json}->decode($res_json);
   

   return 0;
}





#----------------------------------------------------------------------
#
# NAME:  create
#
# DESC:  Create a new file in Google Drive
#
#        https://developers.google.com/drive/api/v3/reference/files/create
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
   my ($h1, $h2, $h3, $h4) = @_;

   my $func = "GoogleAPI::Drive::File::create";

   my $g    = undef;
   my $p    = undef;
   my $body = undef;

   #------------------------------------------------------------
   # class name - GoogleAPI::Drive::File
   #------------------------------------------------------------
   if( $h1 eq 'GoogleAPI::Drive::File' ) {
      $g    = $h2 if ref $h2 eq 'GoogleAPI';
      $p    = $h3 if ref $h3 eq 'HASH';
      $body = $h4 if ref $h4 eq 'HASH';
   }
   else {
      print STDERR "h1 = $h1\n";
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
   

   # If uploading a file
   # POST https://www.googleapis.com/upload/drive/v3/files
   # Not uploading a file - metadata only
   # POST https://www.googleapis.com/drive/v3/files
   my $uri = "https://www.googleapis.com/drive/v3/files";

   $uri = $p->{uri} if $p->{uri} ne "";
   delete $p->{uri};

   my $url = $uri . "?" .
       qq(access_token=) . $g->{oauth2}->{access_token};
   
   foreach ( keys %$p ) {
      $url .= "&" . $_ . "=" . $p->{$_};
   }
   
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
   my $content = $g->{json}->encode($body);

   $req->header('Content-Length' => length $content);
   $req->header('Content-Type'   => "application/json");
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
      print "$func: Did not get JSON - Exiting...\n";
      return 1;
   }
   

   #------------------------------------------------------------
   # Response
   #------------------------------------------------------------
   my $h = $g->{json}->decode($res_json);

   if($h) {
      return bless $h, 'GoogleAPI::Drive::File';
   }
   else {
      return undef;
   }
}




#----------------------------------------------------------------------
#
# NAME:  upload
#
# DESC:  Upload a file in Google Drive
#
#   https://developers.google.com/drive/api/v3/reference/files/create
#   https://developers.google.com/drive/api/v3/reference/files/update
#
#   This provides better details for uploading
#   https://developers.google.com/drive/api/v3/manage-uploads
#
#
# ARGS:  h1 - String 'GoogleAPI::Drive::File' called like this
#             GoogleAPI::Drive::File->upload( $g, ... )
#             This would used for an initial upload
#                OR
#             Blessed object of 'GoogleAPI::Drive::File' called like
#             $file->upload( $g, ... )
#             This would used for an update of the file
#
#        h2 - GoogleAPI Object
#        h3 - Parameters to pass to API via URL
#        h4 - Request Body - see docs for create/update
#             This will be sent as JSON in multipart msg
#
#        filepath  - File to upload
#        mimetype  - Desired mimetype to use in multipart msg
#
# RETN:  
#
# HIST:  
#
#----------------------------------------------------------------------
sub upload {
   my ($h1, $h2, $h3, $h4, $filepath, $mimetype) = @_;

   my $func = "GoogleAPI::Drive::File::upload";

   my $g    = undef;
   my $p    = undef;
   my $body = undef;

   my $update_id;
   
   
   #------------------------------------------------------------
   # class name - GoogleAPI::Drive::File
   #------------------------------------------------------------
   if( $h1 eq 'GoogleAPI::Drive::File' ) {
      $g    = $h2 if ref $h2 eq 'GoogleAPI';
      $p    = $h3 if ref $h3 eq 'HASH';
      $body = $h4 if ref $h4 eq 'HASH';
   }
   elsif( ref $h1 eq 'GoogleAPI::Drive::File' ) {
      if( exists $h1->{id} && ($h1->{id} ne "")) {
         $update_id = $h1->{id};
      }
      else {
         print STDERR "$func: ERROR: File ID not defined to update\n";
         return undef;
      }

      $g    = $h2 if ref $h2 eq 'GoogleAPI';
      $p    = $h3 if ref $h3 eq 'HASH';
      $body = $h4 if ref $h4 eq 'HASH';
   }
   else {
      print STDERR "h1 = $h1\n";
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

   if( ! -e $filepath ) {
      $g->add_error("$func: '$filepath' does not exist");
      return undef;
   }
      
   if( ! -f $filepath ) {
      $g->add_error("$func: '$filepath' is not a file");
      return undef;
   }

   if( $mimetype eq "" ) {
      $mimetype = "application/octet-stream";
   }
   

       
   
   #------------------------------------------------------------
   #
   # Check if the uploadType is set
   # If not set - make the default 'multipart'
   #
   # Setting it to 'media' is pretty useless
   # since it seems no other metadata can be passed such as
   # the filename, parent folder, etc
   #
   #------------------------------------------------------------
   if( ! exists $p->{uploadType} || ($p->{uploadType} eq "") ) {
      $p->{uploadType} = "multipart";
      #$p->{uploadType} = "media";
   }


   # This call is only for media and multipart uploadType
   if( $p->{uploadType} eq "resumable" ) {
      my $msg = "$func: Use upload_resumable calls";
      print STDERR "$msg\n";
      $g->add_error($msg);
      return undef;
   }


   
   #------------------------------------------------------------
   #
   # Set the HTTP METHOD and URI for uploading a file
   # This depends if the intent is to update an existing file
   #
   #   POST If uploading a new file
   #   Drive can have mult files of same name in the same folder
   #
   #   PATCH If you want to overwrite existing file
   #   The file ID is needed to add to the URI
   #
   #------------------------------------------------------------
   my $method = "POST";
   my $uri    = "https://www.googleapis.com/upload/drive/v3/files";

   if( $update_id ne "" ) {
      $method = "PATCH";
      $uri   .= "/" . $update_id;
   }


   # Set any specific URI if passed in
   $uri = $p->{uri} if $p->{uri} ne "";
   delete $p->{uri};

   # Set other params
   my $url = $uri . "?" .
       qq(access_token=) . $g->{oauth2}->{access_token};
   
   foreach ( keys %$p ) {
      $url .= "&" . $_ . "=" . $p->{$_};
   }
   
   $g->add_debug("$func: URL:\n" . 
                 $url . "\n") if $g->{debug_http};


   
   #------------------------------------------------------------
   #
   # Create request - varies depending on the Upload Type
   #
   #------------------------------------------------------------
   my $req;


   #------------------------------------------------------------
   # MEDIA
   #------------------------------------------------------------
   if( $p->{uploadType} eq "media" ) {

      $req = HTTP::Request->new( POST => $url );

      # Slurp in the whole filename - not good for large files...
      my $content;

      if( open FH, "<", $filepath ) {
         local $/ = undef;
         $content = <FH>;
         close FH;
      }
      else {
         $g->add_error("$func: Problem opening '$filepath' to upload");
         return undef;
      }
         
      $req->header('Content-Type'   => $mimetype);
      $req->header('Content-Length' => length $content);
      $req->content($content);

      #print "content = $content\n";
      #print "length = ", (length $content), "\n\n";
   }
   #------------------------------------------------------------
   # MULTIPART
   #------------------------------------------------------------
   elsif( $p->{uploadType} eq "multipart" ) {

      my ($msgbody, $bb) =
          get_multipart_body($g, $func, $body, $filepath, $mimetype);
      
      if( $msgbody eq "" ) {
         $g->add_error("$func: Problem creating message body for upload");
         return undef;
      }
      
      
      # Create the request with Content-type multiplart/related 
      $req = HTTP::Request->new(
         $method => $url,
         [ 'Content-length' => length($msgbody),
           'Content-type'   => qq(multipart/related; boundary="$bb") ],
         $msgbody );
   }
   else {
      $g->add_error("$func: Invalid parameter uploadType value");
      return undef;
   }

   
   $g->add_debug("$func: HTTP REQUEST:\n" . 
                 $req->as_string . "\n") if $g->{debug_http};


   
   my $res_json;

   my $code    = 0;   
   my $success = 0;
   my $tries   = 0;
   
   # Allow multiple chances for success
   while(! $success && $tries < $g->{retry_max}) {

      $tries++;
      
      my $res = $g->{ua}->request($req);

      $g->add_debug("$func: HTTP RESPONSE:\n" . 
                    $res->as_string . "\n") if $g->{debug_http};

      $code = $res->code;

      
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
      $g->add_error("$func: Did not get any JSON");
   }
   

   my $file = undef;
   
   if( $success == 1 ) {
      my $h = $g->{json}->decode($res_json);
      $file = bless $h, 'GoogleAPI::Drive::File' if $h;
   }

   
   return $file, $code;
}






#----------------------------------------------------------------------
#
# NAME:  upload_resumable_init
#
# DESC:  Upload a file in Google Drive
#
#   https://developers.google.com/drive/api/v3/reference/files/create
#   https://developers.google.com/drive/api/v3/reference/files/update
#
#   This provides better details
#   https://developers.google.com/drive/api/v3/manage-uploads
#
#
# ARGS:  h1 - String 'GoogleAPI::Drive::File' called like this
#             GoogleAPI::Drive::File->upload( $g, ... )
#             This would used for an initial upload
#                OR
#             Blessed object of 'GoogleAPI::Drive::File' called like
#             $file->upload( $g, ... )
#             This would used for an update of the file
#
#        h2 - GoogleAPI Object
#        h3 - Parameters to pass to API via URL
#        h4 - Request Body - see docs for create/update
#             This will be sent as JSON in multipart msg
#
#        filepath OPTIONAL - used to get file size for
#                 X-Upload-Content-Length in HTTP header
#
#        mimetype OPTIONAL - used to set X-Upload-Content-Type
#
#
# RETN:  upload_id - Good for one week
#                    Used by upload_resumable_single/multiple calls
#
#
# HIST:  
#
#----------------------------------------------------------------------
sub upload_resumable_init {
   my ($h1, $h2, $h3, $h4, $filepath, $mimetype) = @_;

   my $func = "GoogleAPI::Drive::File::upload_resumable_init";

   my $g    = undef;
   my $p    = undef;
   my $body = undef;

   my $update_id;

   #------------------------------------------------------------
   # class name - GoogleAPI::Drive::File
   #------------------------------------------------------------
   if( $h1 eq 'GoogleAPI::Drive::File' ) {
      $g    = $h2 if ref $h2 eq 'GoogleAPI';
      $p    = $h3 if ref $h3 eq 'HASH';
      $body = $h4 if ref $h4 eq 'HASH';
   }
   elsif( ref $h1 eq 'GoogleAPI::Drive::File' ) {
      if( exists $h1->{id} && ($h1->{id} ne "")) {
         $update_id = $h1->{id};
      }
      else {
         print STDERR "$func: ERROR: File ID not defined to update\n";
         return undef;
      }

      $g    = $h2 if ref $h2 eq 'GoogleAPI';
      $p    = $h3 if ref $h3 eq 'HASH';
      $body = $h4 if ref $h4 eq 'HASH';
   }
   else {
      print STDERR "h1 = $h1\n";
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

   if( $filepath ne "" ) {
      if( ! -e $filepath ) {
         $g->add_error("$func: '$filepath' does not exist");
         return undef;
      }
      
      if( ! -f $filepath ) {
         $g->add_error("$func: '$filepath' is not a file");
         return undef;
      }
   }


   
   #------------------------------------------------------------   
   # Set the uploadType to resumable
   #------------------------------------------------------------
   $p->{uploadType} = "resumable";



   #------------------------------------------------------------
   #
   # Set the HTTP METHOD and URI for uploading a file
   # This depends if the intent is to update an existing file
   #
   #   POST If uploading a new file
   #   Drive can have mult files of same name in the same folder
   #
   #   PATCH If you want to overwrite existing file
   #   The file ID is needed to add to the URI
   #
   #------------------------------------------------------------
   my $method = "POST";
   my $uri    = "https://www.googleapis.com/upload/drive/v3/files";

   if( $update_id ne "" ) {
      $method = "PATCH";
      $uri   .= "/" . $update_id;
   }

   
   # Set any specific URI if passed in
   $uri = $p->{uri} if $p->{uri} ne "";
   delete $p->{uri};

   # Set other params
   my $url = $uri . "?" .
       qq(access_token=) . $g->{oauth2}->{access_token};
   
   foreach ( keys %$p ) {
      $url .= "&" . $_ . "=" . $p->{$_};
   }
   
   $g->add_debug("$func: URL:\n" . 
                 $url . "\n") if $g->{debug_http};

   
   #------------------------------------------------------------
   #
   # CREATE REQUEST 
   #
   #   Need to be careful setting length using header
   #   Need to use same encoding as upload - MIME Base64
   #      'X-Upload-Content-Type'   => $mimetype,
   #      'X-Upload-Content-Length' => (stat $filepath)[7] ],
   #   Leave out now since they are optional
   #   It would be expensive to opne the file and encode
   #   just to get the size
   #
   #------------------------------------------------------------
   my $msgbody = $g->{json}->encode($body);

   my $req = HTTP::Request->new(
      $method => $url,      
      [ 'Content-length' => length($msgbody),
        'Content-type'   => qq(application/json; charset=UTF-8) ],
      $msgbody );

   
   $g->add_debug("$func: HTTP REQUEST:\n" . 
                 $req->as_string . "\n") if $g->{debug_http};

   
   my $success  = 0;
   my $tries    = 0;
   my $location = "";
   
   
   # Allow multiple chances for success
   while(! $success && $tries < $g->{retry_max}) {
      
      $tries++;
      
      my $res = $g->{ua}->request($req);

      $g->add_debug("$func: HTTP RESPONSE:\n" . 
                    $res->as_string . "\n") if $g->{debug_http};

      
      if($res->is_success) {

         $location = $res->header('Location');
            
         if( $location eq "" ) {
            $g->add_error("$func: Did not get Location calling $url\n");
         }
         else {
            $success  = 1;
         }
      }
      else {
         $g->add_error("$func: HTTP call failed - Exiting...");
         $g->add_error("$func: " . $res->status_line);
         $g->add_error("$func: try = $tries");
         
         # If we don't have this info in the debug log - add it to error log
         if(! $g->{debug_http}) {
            $g->add_error("$func: HTTP REQUEST:\n"  . $req->as_string . "\n");
            $g->add_error("$func: HTTP RESPONSE:\n" . $res->as_string . "\n");
         }
         
         # Pause before trying again
         sleep $g->{retry_wait} if $tries < $g->{retry_max};        
      }
   }



   # Make sure we got a location back
   if( $location eq "" ) {
      $g->add_error( "$func: Did not get Location\n" );
   }
   else {
      # If we had to retry, write a success msg to the error log
      if($tries > 1) {
         $g->add_error("$func: successful on try $tries");
      }
   }


   # Get the upload_id parameter out of the 
   my $upload_id = "";

   if( $location =~ /(\?|\&)upload_id=(.*)\&?/ ) {
      $upload_id = $2;
   }

   
   return $upload_id;
}




#----------------------------------------------------------------------
#
# NAME:  upload_resumable_single
#
# DESC:  Upload a file in Google Drive
#        in a single call using 'resumable' uploadType
#
#   https://developers.google.com/drive/api/v3/reference/files/create
#   https://developers.google.com/drive/api/v3/reference/files/update
#
#   This provides better details
#   https://developers.google.com/drive/api/v3/manage-uploads
#
#
# ARGS:  h1 - self
#        h2 - GoogleAPI Object
#        h3 - Parameters to pass to API via URL
#        h4 - Request Body - see docs for create/update
#             This will be sent as JSON in multipart msg#
#
# RETN:  
#
# HIST:  
#
#----------------------------------------------------------------------
sub upload_resumable_single {
   my ($h1, $h2, $h3, $h4, $filepath, $mimetype) = @_;

   my $func = "GoogleAPI::Drive::File::upload_resumable_single";

   my $g    = undef;
   my $p    = undef;
   my $body = undef;

   my $update_id;

   #------------------------------------------------------------
   # class name - GoogleAPI::Drive::File
   #------------------------------------------------------------
   if( $h1 eq 'GoogleAPI::Drive::File' ) {
      $g    = $h2 if ref $h2 eq 'GoogleAPI';
      $p    = $h3 if ref $h3 eq 'HASH';
      $body = $h4 if ref $h4 eq 'HASH';
   }
   elsif( ref $h1 eq 'GoogleAPI::Drive::File' ) {
      if( exists $h1->{id} && ($h1->{id} ne "")) {
         $update_id = $h1->{id};
      }
      else {
         print STDERR "$func: ERROR: File ID not defined to update\n";
         return undef;
      }

      $g    = $h2 if ref $h2 eq 'GoogleAPI';
      $p    = $h3 if ref $h3 eq 'HASH';
      $body = $h4 if ref $h4 eq 'HASH';
   }
   else {
      print STDERR "h1 = $h1\n";
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

   if( ! -e $filepath ) {
      $g->add_error("$func: '$filepath' does not exist");
      return undef;
   }
      
   if( ! -f $filepath ) {
      $g->add_error("$func: '$filepath' is not a file");
      return undef;
   }

   if( $mimetype eq "" ) {
      $mimetype = "application/octet-stream";
   }
   

   #------------------------------------------------------------   
   # Set the uploadType to resumable
   #------------------------------------------------------------
   $p->{uploadType} = "resumable";


   # Make sure the upload_id has been passed in
   if( ! exists $p->{upload_id} || ($p->{upload_id} eq "") ) {
      $g->add_error("$func: parameter upload_id is not set");
      return undef;
   }



   #------------------------------------------------------------
   #
   # Set the HTTP METHOD and URI for uploading a file
   # This depends if the intent is to update an existing file
   #
   #   POST If uploading a new file
   #   Drive can have mult files of same name in the same folder
   #
   #   PATCH If you want to overwrite existing file
   #   The file ID is needed to add to the URI
   #
   #   The file upload/update/replace still seems to work with
   #   either a POST or PATCH as long as the upload_id was obtained
   #   using PATCH with File ID - see upload_resumable_init
   #   But not sure if file metadata is updated using a POST
   #
   #------------------------------------------------------------
   my $method = "POST";
   my $uri    = "https://www.googleapis.com/upload/drive/v3/files";

   if( $update_id ne "" ) {
      $method = "PATCH";
      $uri   .= "/" . $update_id;
   }

   
   # Set any specific URI if passed in
   $uri = $p->{uri} if $p->{uri} ne "";
   delete $p->{uri};

   # Set other params
   my $url = $uri . "?" .
       qq(access_token=) . $g->{oauth2}->{access_token};
   
   foreach ( keys %$p ) {
      $url .= "&" . $_ . "=" . $p->{$_};
   }
   
   $g->add_debug("$func: URL:\n" . 
                 $url . "\n") if $g->{debug_http};


   
   #------------------------------------------------------------
   #
   #  CREATE REQUEST
   #
   #------------------------------------------------------------
   my ($msgbody, $bb) =
       get_multipart_body($g, $func, $body, $filepath, $mimetype);

   if( $msgbody eq "" ) {
      $g->add_error("$func: Problem creating message body for upload");
      return undef;
   }

   
   # Create the request with Content-type multiplart/related 
   my $req = HTTP::Request->new(
      $method => $url,
      [ 'Content-length' => length($msgbody),
        'Content-type'   => qq(multipart/related; boundary="$bb") ],
      $msgbody );

   
   $g->add_debug("$func: HTTP REQUEST:\n" . 
                 $req->as_string . "\n") if $g->{debug_http};
   


   my $res_json;

   my $code    = 0;
   my $success = 0;
   my $tries   = 0;
   
   # Allow multiple chances for success
   while(! $success && $tries < $g->{retry_max}) {
      $tries++;
      
      my $res = $g->{ua}->request($req);

      $g->add_debug("$func: HTTP RESPONSE:\n" . 
                    $res->as_string . "\n") if $g->{debug_http};

      $code = $res->code;
      
      # Response with code 5xx means file upload was interrupted
      if( ($code >= 500) && ($code <= 599) ) {
         $res_json = $res->content;
         $success  = 2;
      }
      elsif($res->is_success) {
         $res_json = $res->content;
         $success  = 1;

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


   # See if we got some JSON back
   if( $res_json eq "" ) {
      $g->add_error("$func: Did not get any JSON");
   }


   my $file = undef;
   
   if( $success == 1 ) {
      my $h = $g->{json}->decode($res_json);
      $file = bless $h, 'GoogleAPI::Drive::File' if $h;
   }

   
   return $file, $code;
}






#----------------------------------------------------------------------
#
# NAME:  upload_resumable_multiple
#
# DESC:  Upload a file in Google Drive
#        in MULTIPLE calls using 'resumable' uploadType
#
#   https://developers.google.com/drive/api/v3/reference/files/create
#   https://developers.google.com/drive/api/v3/reference/files/update
#
#   This provides better details
#   https://developers.google.com/drive/api/v3/manage-uploads
#
#
# ARGS:  h1 - self
#        h2 - GoogleAPI Object
#        h3 - Parameters to pass to API via URL
#        h4 - Request Body - see docs for create/update
#             This will be sent as JSON in multipart msg#
#
#
# RETN:  
#
# HIST:  
#
#----------------------------------------------------------------------
sub upload_resumable_multiple {
   my ($h1, $h2, $h3, $h4,
       $filepath, $mimetype, $chunksize) = @_;

   my $func = "GoogleAPI::Drive::File::upload_resumable_multiple";

   my $g    = undef;
   my $p    = undef;
   my $body = undef;

   my $update_id;

   #------------------------------------------------------------
   # class name - GoogleAPI::Drive::File
   #------------------------------------------------------------
   if( $h1 eq 'GoogleAPI::Drive::File' ) {
      $g    = $h2 if ref $h2 eq 'GoogleAPI';
      $p    = $h3 if ref $h3 eq 'HASH';
      $body = $h4 if ref $h4 eq 'HASH';
   }
   elsif( ref $h1 eq 'GoogleAPI::Drive::File' ) {
      if( exists $h1->{id} && ($h1->{id} ne "")) {
         $update_id = $h1->{id};
      }
      else {
         print STDERR "$func: ERROR: File ID not defined to update\n";
         return undef;
      }

      $g    = $h2 if ref $h2 eq 'GoogleAPI';
      $p    = $h3 if ref $h3 eq 'HASH';
      $body = $h4 if ref $h4 eq 'HASH';
   }
   else {
      print STDERR "h1 = $h1\n";
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

   if( ! -e $filepath ) {
      $g->add_error("$func: '$filepath' does not exist");
      return undef;
   }
      
   if( ! -f $filepath ) {
      $g->add_error("$func: '$filepath' is not a file");
      return undef;
   }

   if( $mimetype eq "" ) {
      $mimetype = "application/octet-stream";
   }
   

   #------------------------------------------------------------   
   # Set the uploadType to resumable
   #------------------------------------------------------------
   $p->{uploadType} = "resumable";


   # Make sure the upload_id has been passed in
   if( ! exists $p->{upload_id} || ($p->{upload_id} eq "") ) {
      $g->add_error("$func: parameter upload_id is not set");
      return undef;
   }



   #------------------------------------------------------------
   #
   # Set the HTTP METHOD and URI for uploading a file
   # This depends if the intent is to update an existing file
   #
   #   POST If uploading a new file
   #   Drive can have mult files of same name in the same folder
   #
   #   PATCH If you want to overwrite existing file
   #   The file ID is needed to add to the URI
   #
   #   The file upload/update/replace still seems to work with
   #   either a POST or PATCH as long as the upload_id was obtained
   #   using PATCH with File ID - see upload_resumable_init
   #   But not sure if file metadata is updated using a POST
   #
   #------------------------------------------------------------
   my $method = "POST";
   my $uri    = "https://www.googleapis.com/upload/drive/v3/files";

   if( $update_id ne "" ) {
      $method = "PATCH";
      $uri   .= "/" . $update_id;
   }

   
   # Set any specific URI if passed in
   $uri = $p->{uri} if $p->{uri} ne "";
   delete $p->{uri};

   # Set other params
   my $url = $uri . "?" .
       qq(access_token=) . $g->{oauth2}->{access_token};
   
   foreach ( keys %$p ) {
      $url .= "&" . $_ . "=" . $p->{$_};
   }
   
   $g->add_debug("$func: URL:\n" . 
                 $url . "\n") if $g->{debug_http};


   
   #------------------------------------------------------------
   #
   # Open the file and read in as chunks and
   # upload each chuck using a HTTP call
   #
   #
   #  CREATE REQUEST
   #
   #------------------------------------------------------------
   my $fh;
   if( !  open $fh, '<', $filepath) {
      $g->add_error("$func: problem opening '$filepath'");
      return undef;
   }
   
   binmode $fh;

   #------------------------------------------------------------
   # Per Google this size should be a multiple of 256k
   #    4 x 256k = 1mb
   # Set to the default chunksize if not passed in - 16mb
   #------------------------------------------------------------
   $chunksize = 64 * 256 * 1024 if ! $chunksize;   
   
   my $ok;
   my $filesize  = (stat $filepath)[7];
   my $buffer    = "";
   my $buflen    = 0;
   my $start     = 0;
   my $end       = 0;
   my $res_json  = "";
   my $code      = 0;
   my $chunk     = 1;

   my $chunkcnt = int($filesize / $chunksize);
   $chunkcnt++ if ($filesize % $chunksize) > 0;

   my $tries    = 0;
   my $maxtries = ($chunkcnt * 2) || 2;

   if( $g->{debug} ) {
      $g->add_debug("$func: CHUNKCNT = $chunkcnt\n");
      $g->add_debug("$func: MAXTRIES = $maxtries\n");
   }
   
   
   while ( ($chunk <= $chunkcnt) && ($tries < $maxtries) ) {
      $tries++;
      
      #--------------------------------------------------
      #
      # If the buffer was not uploaded completely
      # then some will be left over - so don't read again
      #
      #--------------------------------------------------
      if( $buffer eq "" ) {
         $ok = read $fh, $buffer, $chunksize;

         # Something bad happened...
         if( not defined $ok ) {
            $g->add_error("$func: Big problem reading file - $!");
            last;
         }

         # Done reading file
         last if not $ok;         
      }

      
      $buflen = length($buffer);
      $end    = $start + $buflen - 1;


      
      #--------------------------------------------------
      #
      # Create the request
      #
      #--------------------------------------------------
      my $req = HTTP::Request->new(
         PUT => $url,
         [ 'Content-length' => $buflen,
           'Content-Range'  => sprintf("bytes %d-%d/%d",
                                       $start, $end, $filesize) ],
         $buffer );
      
   
      $g->add_debug("$func: HTTP REQUEST:\n" . 
                    $req->as_string . "\n") if $g->{debug_http};



      #--------------------------------------------------
      #
      # Make the request and process the codes
      #
      #--------------------------------------------------
      my $res = $g->{ua}->request($req);

      $g->add_debug("$func: HTTP RESPONSE:\n" . 
                    $res->as_string . "\n") if $g->{debug_http};

      $code = $res->code;


      
      #--------------------------------------------------
      #
      # 308 Resume Incomplete
      #
      # This code comes back when a chunk is uploaded
      # but the entire file upload in not complete
      #
      # Get 'Range' in HTTP header - the format is
      #    Range: bytes=0-318767103
      #
      # The 2nd number should match the request above
      #    Content-Range: bytes 301989888-318767103/323970268
      #
      # If these do not match then the next upload
      # should start one byte after what was given back in Range:
      #
      # Modify the current buffer by removing bytes from the front
      # and the logic above will use the remaining buffer
      # instead of getting the next chunk from the file
      #
      #--------------------------------------------------
      if( $code == 308 ) {
         if( $res->header('Range') =~ /bytes=(\d+)-(\d+)/ ) {
            my $end2 = $2;

            if( $end2 == $end ) {
               $start  = $start + $buflen;
               $buffer = "";
               $chunk++;
            }
            elsif( $end2 < $end ) {
               $start  = $end2 + 1;
               $buffer = substr $buffer, $buflen-($end-$end2), $buflen, '';
            }
            else {
               my $msg = "$func: Range value is greater than expected " .
                   $end2 . " > " . $end;
               print STDERR "$msg\n";
               $g->add_error($msg);
               last;
            }
         }
         else {
            $g->add_error("$func: Bad Range in HTTP response");
            last;
         }
      }
      #--------------------------------------------------
      #
      # Response code 5xx
      # File upload was interrupted
      #
      #--------------------------------------------------
      elsif( ($code >= 500) && ($code <= 599) ) {
         my $msg = "$func: Upload interrupted";
         print STDERR "$msg\n";
         $g->add_error($msg);
         last;
      }
      #--------------------------------------------------
      #
      # This should be returned
      # when the last chunk uploaded
      #
      #--------------------------------------------------
      elsif($res->is_success) {
         $res_json = $res->content;
         last;
      }
      #--------------------------------------------------
      #
      # Something unexpected was returned so exit the loop
      #
      #--------------------------------------------------
      else {
         $g->add_error("$func: HTTP call failed - Exiting...");
         $g->add_error("$func: " . $res->status_line);

         # If we don't already have this info in the debug log
         # add it to the error log
         if(! $g->{debug_http}) {
            $g->add_error("$func: HTTP REQUEST:\n" . 
                          $req->as_string . "\n");
            $g->add_error("$func: HTTP RESPONSE:\n" . 
                          $res->as_string . "\n");
         }

         last;
      }
   }


   close $fh;


   
   #------------------------------------------------------------
   # See if we got some JSON back - create File object
   #------------------------------------------------------------
   my $file = undef;

   if( $res_json ne "" ) {
      $file = bless $g->{json}->decode($res_json), 'GoogleAPI::Drive::File';
   }
   else {
      $g->add_error("$func: Did not get any JSON in HTTP response");
   }

   
   
   return $file, $code;
}










#----------------------------------------------------------------------
#
# NAME:  copy
#
# DESC:  Copy a file to one or more folders
#
#        https://developers.google.com/drive/api/v3/reference/files/copy
#
#
# ARGS:  $p        Parameters to pass to API
#                  { parents  => [ <folder1_id>, <folder2_id>, <folder3_id> ],
#                    name     => <file_name>
#                  }
#
#                  If 'parents' is omitted, file will be copied to MyDrive.
#                  If 'name' is omitted, file name will be "Copy of " +
#                     original file name
#
# RETN:  
#
# HIST:  
#
#----------------------------------------------------------------------
sub copy {
   my ($f, $p) = @_;

   my $func = "GoogleAPI::Drive::File::copy";
   

   if( ref $f ne "GoogleAPI::Drive::File" ) {
      $f->{g}->add_error("$func: Incorrect object");
      return 1;
   }

   if( $f->{g}->{oauth2}->{access_token} eq "" ) {
      $f->{g}->add_error("$func: access_token not defined");
      return 1;
   }

   my $g = $f->{g};


   my $uri =
       "https://www.googleapis.com/drive/v3/files/" . $f->{id} . "/copy";

   
   my $url = $uri . "?" .
       qq(access_token=) . $f->{g}->{oauth2}->{access_token};

   # For Team Drive files
   $url .= '&supportsAllDrives=true';

   #foreach ( "supportsTeamDrives",
   #          "supportsAllDrives" ) {      
   #   $url .= "&" . $_ . "=" . $p->{$_} if $p->{$_};
   #}

   
   my $req = HTTP::Request->new(POST => $url);

   #------------------------------------------------------------
   #
   # If the parents array is not supplied the file will
   # be copied to the user's My Drive root folder.
   #
   # If multiple parents (folder IDs) are given, the API will
   # make a single copy of the original file and make it a child
   # of all the parents.  This is probably NOT what we want.
   #
   # This code will make a new copy of the original file in EACH
   # parent folder, so the API call will be made once for each
   # parent.
   #
   #------------------------------------------------------------
   # Convert incoming data to JSON
   # Update request object
   #------------------------------------------------------------
   my @parent_ids;
   my $name;
   if(ref $p eq "HASH") {
      if(exists $p->{parents}) {
         if(ref $p->{parents} eq "ARRAY") {
            @parent_ids = @{$p->{parents}};
            delete $p->{parents};
         }
         # Accept a scalar string value for parents
         elsif(ref $p->{parents} eq "") {
            if($p->{parents} eq '') {
               delete $p->{parents};
            }
            else {
               @parent_ids = ($p->{parents});
            }
         }
         else {
            $g->add_error(sprintf "%s: Data type '%s' not valid for parents",
                          $func, (ref $p->{parents}));
            return 1;
         }
      }

      if(exists $p->{name}) {
         $name = $p->{name};
         delete $p->{name} if $p->{name} eq '';
      }
   }

   
   # If new file name is not set, use original file name for all copies
   if($name eq '') {
      $f->get({supportsAllDrives => "true"});

      $name = $f->{metadata}->{name};
      print "GOT NAME = '$name'\n";

      if($name ne '') {
         $p->{name} = $name;
      }
   }

   
   
   # If no parents, add 'undef' value to parent_ids array so the loop
   # won't be skipped
   if(! scalar @parent_ids) {
      push @parent_ids, undef;
   }

   my @copies;
   
   for my $parent_id (@parent_ids) {
      # Replace parent ID in original parameter hash
      if($parent_id eq '') {
         # No specification of parent, so copy will go to MyDrive
         delete $p->{parents};
      }
      else {
         $p->{parents} = [ $parent_id ];
      }
      
      my $content = $g->{json}->encode($p);
      
      $req->header('Content-Length' => length $content);
      $req->header('Content-Type'   => "application/json");
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
         print "$func: Did not get JSON - Exiting...\n";
         return 1;
      }


      my $meta = $f->{g}->{json}->decode($res_json);

      # Add the parent ID to the metadata
      $meta->{parent} = $parent_id;

      push @copies, $meta;
   }
   
   $f->{copies} = \@copies;

   
   return 0;
}





#----------------------------------------------------------------------
#
# NAME:  delete
#
# DESC:  Delete a file or folders
#
#        https://developers.google.com/drive/api/v3/reference/files/delete
#
#
# ARGS:  
#
# RETN:  
#
# HIST:  
#
#----------------------------------------------------------------------
sub delete {
   my ($f, $p) = @_;

   my $func = "GoogleAPI::Drive::File::delete";
   

   if( ref $f ne "GoogleAPI::Drive::File" ) {
      $f->{g}->add_error("$func: Incorrect object");
      return 1;
   }

   if( $f->{g}->{oauth2}->{access_token} eq "" ) {
      $f->{g}->add_error("$func: access_token not defined");
      return 1;
   }

   my $g = $f->{g};

   my $uri =
       "https://www.googleapis.com/drive/v3/files/" . $f->{id};

   
   my $url = $uri . "?" .
       qq(access_token=) . $f->{g}->{oauth2}->{access_token};

   foreach ( "supportsTeamDrives",
             "supportsAllDrives" ) {      
      $url .= "&" . $_ . "=" . $p->{$_} if $p->{$_};
   }

   
   my $req = HTTP::Request->new(DELETE => $url);

   $g->add_debug("$func: HTTP REQUEST:\n" . 
                 $req->as_string . "\n") if $g->{debug_http};
   

   my $res = $f->{g}->{ua}->request($req);

   my $res_json;
   
   if(! $res->is_success) {
      $g->add_error("$func: HTTP call failed - Exiting...");
      $g->add_error("$func: " . $res->status_line);
      
      # If we don't already have this info in the debug log
      # add it to the error log
      if(! $g->{debug_http}) {
         $g->add_error("$func: HTTP REQUEST:\n" . 
                       $req->as_string . "\n");
         $g->add_error("$func: HTTP RESPONSE:\n" . 
                       $res->as_string . "\n");
      }

      return 1;
   }

   
   return 0;
}
   


#----------------------------------------------------------------------
#
# NAME:  move
#
# DESC:  Move a file from one folder to another.
#        This function uses the Google file update method to add a new
#        parent (destination folder) to the file and remove a parent
#        (source folder)
#
#        https://developers.google.com/drive/api/v3/reference/files/update
#
#
# ARGS:  $p        Parameters to pass to API
#                  { dest*   => <dest_folder_id>,
#                    source* => <source_folder_id>
#                  }
#
#               *will be passed in URI, not request body
#
# RETN:  
#
# HIST:  
#
#----------------------------------------------------------------------
sub move {
   my ($f, $p) = @_;

   my $func = "GoogleAPI::Drive::File::move";
   

   if( ref $f ne "GoogleAPI::Drive::File" ) {
      $f->{g}->add_error("$func: Incorrect object");
      return 1;
   }

   if( $f->{g}->{oauth2}->{access_token} eq "" ) {
      $f->{g}->add_error("$func: access_token not defined");
      return 1;
   }

   my $g = $f->{g};


   #============================================================
   # Construct request URL
   #============================================================
   my $uri =
       "https://www.googleapis.com/drive/v3/files/" . $f->{id};

   
   my $url = $uri . "?" .
       qq(access_token=) . $f->{g}->{oauth2}->{access_token};

       
   #------------------------------------------------------------
   # Source parent
   #------------------------------------------------------------
   if(exists $p->{source}) {
      $url .= "&removeParents=" . $p->{source};
      delete $p->{source};
   }
   else {
      $g->add_error("$func: source parent required");
      return 1;
   }
   
   #------------------------------------------------------------
   # Destination parent
   #------------------------------------------------------------
   if(exists $p->{dest}) {
      $url .= "&addParents=" . $p->{dest};
      delete $p->{dest};
   }
   else {
      $g->add_error("$func: destination parent required");
      return 1;
   }


   #------------------------------------------------------------
   # Convert some incoming parameters to URL components
   #------------------------------------------------------------

   # Make sure we specify supportsAllDrives
   my $saw_all_drives = 0;
   
   foreach ( qw(supportsTeamDrives
             supportsAllDrives
             keepRevisionForever
             ocrLanguage
             useContentAsIndexableText
             alt
             fields
             prettyPrint
             quotaUser
             userIp) ) {
      
      if(exists $p->{$_}) {
         $url .= "&" . $_ . "=" . $p->{$_};
         delete $p->{$_};

         $saw_all_drives = 1 if $_ eq "supportsAllDrives";
      }
   }

   # Add supportsAllDrives param if we did not receive it
   if(! $saw_all_drives) {
      $url .= "&supportsAllDrives=true";
   }

   #------------------------------------------------------------
   # Use PATCH call to "update" the file
   #------------------------------------------------------------
   my $req = HTTP::Request->new(PATCH => $url);

   # Write remaining parameters to request body as JSON
   my $content = $g->{json}->encode($p);
      
   $req->header('Content-Length' => length $content);
   $req->header('Content-Type'   => "application/json");
   $req->content($content);
   
   #print "content = $content\n";
   #print "length = ", (length $content), "\n\n";
   
   $g->add_debug("$func: HTTP REQUEST:\n" . 
                 $req->as_string . "\n") if $g->{debug_http};
      
   
   #------------------------------------------------------------
   # Send request and get response
   #------------------------------------------------------------
   my $res = $g->{ua}->request($req);
   
   $g->add_debug("$func: HTTP RESPONSE:\n" . 
                 $res->as_string . "\n") if $g->{debug_http};
   
   my $res_json;
   
   if($res->is_success) {
      $res_json = $res->content;
   }
   else {
      $g->add_error("$func: HTTP call failed - Exiting...");
      $g->add_error("$func: " . $res->status_line);
      
      # If we don't already have this info in the debug log
      # add it to the error log
      if(! $g->{debug_http}) {
         $g->add_error("$func: HTTP REQUEST:\n" . 
                       $req->as_string . "\n");
         $g->add_error("$func: HTTP RESPONSE:\n" . 
                       $res->as_string . "\n");
      }

      return 1;
   }
   

   # Make sure we got some JSON back   
   if( $res_json eq "" ) {
      print "ERROR: Did not get JSON - Exiting...\n";
      return 1;
   }
   
   
   #my $meta = $f->{g}->{json}->decode($res_json);
   
   return 0;
}





#----------------------------------------------------------------------
#
# NAME:  get_multipart_body
#
# DESC:  
#
#
# ARGS:  
#
# RETN:  
#
# HIST:  
#
#----------------------------------------------------------------------
sub get_multipart_body {
   my ($g, $func, $body, $filepath, $mimetype) = @_;

   # UUID for boundary
   my $ug   = Data::UUID->new;
   my $uuid = $ug->create();

   my $bb = $ug->to_string( $uuid );
   $bb =~ s/-//g;

   # CRLF
   my $rn = "\r\n";

   my $delim1 = $rn . "--" . $bb . $rn;
   my $delim2 = $rn . "--" . $bb . "--";

   my $msgbody;

   # Slurp in the file and encode base64
   if( open FH, "<", $filepath ) {
      local $/ = undef;
      
      $msgbody =
          $delim1 .
          "Content-type: application/json; charset=UTF-8" . $rn . $rn .
          $g->{json}->encode($body) .
          $delim1 .
          "Content-type: $mimetype" . $rn .
          "Content-Transfer-Encoding: base64" . $rn . $rn .
          encode_base64(<FH>) .             
          $delim2;
      
      close FH;
   }
   else {
      $g->add_error("$func: Problem opening '$filepath' to upload");
   }

   return $msgbody, $bb;
}




1;

