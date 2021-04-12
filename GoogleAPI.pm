#======================================================================
#
# NAME:  GoogleAPI.pm
#
# DESC:  Google API
#
#        OAuth2 - https://developers.google.com/identity/
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
package GoogleAPI;

use strict;

use Data::Dumper;
use File::Basename;
use HTTP::Request::Common qw(GET POST PUT);
use JSON;
use JSON::WebToken;
use LWP::UserAgent;
use MIME::Base64;
use Time::Local;
use URI::Escape;




#----------------------------------------------------------------------
#
# NAME:  new
#
# DESC:  Create a new object
#
# ARGS:  $h1 - 'GoogleAPI'
#        $h2 - undef|HASH
#
# RETN:  blessed object
#
# HIST:  
#
#----------------------------------------------------------------------
sub new {
   my ($h1, $h2) = @_;

   my $h = undef;
   
   #------------------------------------------------------------
   # class name - GoogleAPI->new();
   #------------------------------------------------------------
   if($h1 eq 'GoogleAPI') {
      $h = $h2 if ref $h2 eq 'HASH';
   }
   else {
      print STDERR 
          "GoogleAPI::new ",
          "ERROR: Invalid argument passed\n";
      return undef; 
   }
   

   #------------------------------------------------------------
   # Define Object structure
   #------------------------------------------------------------
   my $d = { storage_type      => '',
             storage_dir       => '',
             serviceacct_sub   => '',
             serviceacct_useid => '',
             oauth2            => { access_token   => '',
                                    client_id      => '',
                                    client_secret  => '',
                                    client_email   => '',
                                    private_key    => '',
                                    code           => '',
                                    expires        => '',
                                    redirect_uri   => '',
                                    refresh_token  => '',
                                    scope          => ''  },
             auth_uri       => '',
             token_uri      => '',
             http_timeout   => 30,
             http_proxy     => '',
             https_proxy    => '',
             retry_max      => 5,
             retry_wait     => 3,
             debug          => 0,
             debug_http     => 0,
             debug_log      => [ ],
             error_log      => [ ]  };

   
   #------------------------------------------------------------
   # Enforce structure
   # Copy each field if it exists with same ref type
   #------------------------------------------------------------
   foreach (keys %$d) {
      if( exists $h->{$_} && (ref $h->{$_} eq ref $d->{$_}) ) {
         $d->{$_} = $h->{$_};
      }
   }


   # Check the storage directory
   if( ! -d $d->{storage_dir} ) { 
      print STDERR "GoogleAPI::new ", "ERROR: Invalid Storage Dir\n";
      return undef; 
   }      
   
   
   # Check storage_type - 'user' or 'serviceacct' - default is 'user'
   if( ($d->{storage_type} ne "user") &&
       ($d->{storage_type} ne "serviceacct") ) {
      $d->{storage_type} = "user";
   }


   # Check serviceacct_useid - 'id' or 'email' - default is 'id'
   if( (lc $d->{serviceacct_useid} ne "id") &&
       (lc $d->{serviceacct_useid} ne "email") ) {
      $d->{serviceacct_useid} = "id";
   }


   # Set the default Google Auth url if not provided
   $d->{auth_uri} = "https://accounts.google.com/o/oauth2/auth"
       if $d->{auth_uri} eq "";
   

   # Set the default Google Token url if not provided
   $d->{token_uri} = "https://www.googleapis.com/oauth2/v4/token"
   #$d->{token_uri} = "https://accounts.google.com/o/oauth2/token"
       if $d->{token_uri} eq "";


   #------------------------------------------------------------
   # Read the OAuth2 info from the storage directory
   # Depends on the storage_type
   #------------------------------------------------------------
   if( $d->{storage_type} eq "user" ) {
      foreach my $f ( keys %{$d->{oauth2}} ) {
         if( open FH, "<", $d->{storage_dir} . "/$f" ) {
            my @lines = <FH>;
            chomp @lines;
            close FH;
            
            if( $f eq "scope" ) {
               $d->{oauth2}->{$f} = join " ", @lines;
            }
            else {
               $d->{oauth2}->{$f} = $lines[0];
            }
         }
      }
   }
   elsif( $d->{storage_type} eq "serviceacct" ) {

      my $subname = $d->{serviceacct_sub} || "default";

      foreach my $f ( "access_token", "expires" ) {
         if( open FH, "<", $d->{storage_dir} . "/$subname" . "_" . $f ) {
            my @lines = <FH>;
            chomp @lines;
            close FH;
            
            $d->{oauth2}->{$f} = $lines[0];
         }
      }

      # Look for token_uri - if it exists use it
      if( open FH, "<", $d->{storage_dir} . "/token_uri" ) {
         my @lines = <FH>; chomp @lines; close FH;         
         $d->{token_uri} = $lines[0];
      }

      if( open FH, "<", $d->{storage_dir} . "/client_id" ) {
         my @lines = <FH>; chomp @lines; close FH;         
         $d->{oauth2}->{client_id} = $lines[0];
      }

      if( open FH, "<", $d->{storage_dir} . "/client_email" ) {
         my @lines = <FH>; chomp @lines; close FH;         
         $d->{oauth2}->{client_email} = $lines[0];
      }
      
      if( open FH, "<", $d->{storage_dir} . "/private_key" ) {
         my @lines = <FH>; chomp @lines; close FH;         
         $d->{oauth2}->{private_key} = join "\n", @lines;
      }

      if( open FH, "<", $d->{storage_dir} . "/scope" ) {
         my @lines = <FH>; chomp @lines; close FH;         
         $d->{oauth2}->{scope} = join " ", @lines;
      }
   }

   

   #------------------------------------------------------------
   # JSON object
   #------------------------------------------------------------   
   my $json = JSON->new->allow_nonref;

   $d->{json} = $json;


   #------------------------------------------------------------
   # LWP Object
   #------------------------------------------------------------   
   my $ua = new LWP::UserAgent;

   $ua->timeout( $d->{http_timeout} );

   $d->{ua} = $ua;
   
      
   return bless $d, 'GoogleAPI';
}




#----------------------------------------------------------------------
#
# NAME:  error log
#
# DESC:  
#
# ARGS:  
#
# RETN:  
#
# HIST:  
#
#----------------------------------------------------------------------
sub add_error {
   my ($self, $msg) = @_;

   push @{$self->{error_log}}, $msg;
}


sub dump_error {
   my ($self) = @_;

   my $lastmeth;
   foreach ( @{$self->{error_log}} ) {
      my ($thismeth) = split /\:/, $_;
      print "\n\n" if $thismeth ne $lastmeth;
      $lastmeth = $thismeth;

      print "$_\n";
   }
}




#----------------------------------------------------------------------
#
# NAME:  debug log
#
# DESC:  
#
# ARGS:  
#        
# RETN:  
#
# HIST:  
#
#----------------------------------------------------------------------
sub add_debug {
   my ($self, $msg) = @_;

   push @{$self->{debug_log}}, $msg;
}

sub dump_debug {
   my ($self) = @_;

   my $lastmeth;
   foreach ( @{$self->{debug_log}} ) {
      my ($thismeth) = split /\:/, $_;
      print "\n\n" if $thismeth ne $lastmeth;
      $lastmeth = $thismeth;

      print "$_\n";
   }
}



#----------------------------------------------------------------------
#
# NAME:  oauth2_get_code_url
#
# DESC:  Get the URL to put into a browser which will get
#        Google authentication from a user and redirect
#        to given url and provide the access code in the
#        query string
#
#
#
#
# ARGS:  $h1 - 'GoogleAPI'
#
# RETN:  URL to copy into web browser
#
# HIST:  
#
#----------------------------------------------------------------------
sub oauth2_get_code_url {
   my ($self) = @_;

   my $func = "oauth2_get_code_url";
   
   if( $self->{oauth2}->{client_id} eq "" ) {
      $self->add_error("$func: client_id not defined");
      return undef;
   }

   if( $self->{oauth2}->{redirect_uri} eq "" ) {
      $self->add_error("$func: redirect_uri not defined");
      return undef;
   }

   if( $self->{oauth2}->{scope} eq "" ) {
      $self->add_error("$func: scope not defined");
      return undef;
   }


   my $url = $self->{auth_uri} . "?" .
       qq(client_id=)    . $self->{oauth2}->{client_id}     . "&" .
       qq(redirect_uri=) . $self->{oauth2}->{redirect_uri}  . "&" .
       qq(scope=)        . $self->{oauth2}->{scope}         . "&" .
       qq(response_type=code)                             . "&" .
       qq(include_granted_scopes=true)                    . "&" .
       qq(access_type=offline);


   $self->add_debug("$func: URL = $url" . "\n");

   
   my $req = HTTP::Request->new(GET => $url);

   $self->add_debug("$func: HTTP REQUEST:\n" . 
                    $req->as_string . "\n") if $self->{debug_http};
   

   my $res = $self->{ua}->request($req);

   $self->add_debug("$func: HTTP RESPONSE:\n" . 
                    $res->as_string . "\n") if $self->{debug_http};
   
   
   my $location = "";


   if($res->is_success) {      
      my $prev = $res->previous;
      
      if( $prev ) {
         $location = $prev->header('Location');
      }
      else {
         my $url2 = $url;
         $url2 =~ s/\s/%20/g;
         
         print "\n";
         print "Problem with the HTTP Header - cannot get 'Location'\n";
         print "\n";
         print "Try to put the following URL into a browser\n";
         print "This may redirect to the correct place\n";
         print "The URL may have the code/string we are looking for\n";
         print "\n";
         print $url2 . "\n";
         print "\n";
         
         #print Dumper($res), "\n";
      }
   }
   else {
      print "ERROR: HTTP call failed to " .
          $self->{auth_uri} . "\n";
      print $res->status_line, "\n";
      return undef;
   }


   if( $location eq "" ) {
      print "ERROR: Did not get Location URL calling " .
          $self->{auth_uri}  . "\n";
      return undef;
   }


   return $location;
}





#----------------------------------------------------------------------
#
# NAME:  oauth2_get_token
#
# DESC:  
#
#
#
# ARGS:  $self   GoogleAPI Object
#        $keep - Do not overwrite files in storage dir
#
# RETN:  Token - also written to the storage dir
#
# HIST:  
#
#----------------------------------------------------------------------
sub oauth2_get_token {
   my ($self, $keep) = @_;

   my $func = "oauth2_get_token";
   
   if( $self->{oauth2}->{client_id} eq "" ) {
      $self->add_error("$func: client_id not defined");
      return undef;
   }

   if( $self->{oauth2}->{client_secret} eq "" ) {
      $self->add_error("$func: client_secret not defined");
      return undef;
   }

    if( $self->{oauth2}->{code} eq "" ) {
      $self->add_error("$func: access code not defined");
      return undef;
   }

   if( $self->{oauth2}->{redirect_uri} eq "" ) {
      $self->add_error("$func: redirect_uri not defined");
      return undef;
   }


   
   my $content =
       qq(code=)          . $self->{oauth2}->{code}            . "&" .
       qq(client_id=)     . $self->{oauth2}->{client_id}       . "&" .
       qq(client_secret=) . $self->{oauth2}->{client_secret}   . "&" .
       qq(redirect_uri=)  . $self->{oauth2}->{redirect_uri}    . "&" .
       qq(grant_type=authorization_code);



   my $h = HTTP::Headers->new(
      Content_Length      => length($content),
      Content_Type        => 'application/x-www-form-urlencoded' );
   
   my $req = HTTP::Request->new(POST => $self->{token_uri}, $h, $content);

   $self->add_debug("$func: HTTP REQUEST:\n" . 
                    $req->as_string . "\n") if $self->{debug_http};

   
   my $res = $self->{ua}->request($req);

   $self->add_debug("$func: HTTP RESPONSE:\n" . 
                    $res->as_string . "\n") if $self->{debug_http};


   my $acc_token_json;
   my $acc_token;

   
   if($res->is_success) {

      $acc_token_json = $res->content;

      $acc_token = $self->{json}->decode($acc_token_json);
   }
   else {
      print "ERROR: HTTP call failed getting access token calling " .
          $self->{token_uri} . "\n";
      print $res->status_line, "\n";
      print $res->content, "\n";
      return undef;
   }



   

   if( (! exists $acc_token->{access_token} ) ||
       ($acc_token->{access_token} eq "")  ) {
      print "ERROR: Did not get access token when calling " .
          $self->{token_uri} . "\n";
      print $res->content, "\n";
      return undef;
   }


   if( (! exists $acc_token->{refresh_token} ) ||
       ($acc_token->{refresh_token} eq "")  ) {
      print "\n";
      print "WARN: Did not get refresh token\n";
      print "      Goto https://myaccount.google.com/permissions \n";
      print "      and remove access for the Third Party App that \n";
      print "      you are using for this token \n";
      print "      Run this again and you should get a refresh token \n";
      print "\n";
   }


   $self->{oauth2}->{access_token}  = $acc_token->{access_token};
   $self->{oauth2}->{expires}       = $acc_token->{expires_in} + time;
   $self->{oauth2}->{refresh_token} = $acc_token->{refresh_token};
   $self->{oauth2}->{scope}         = $acc_token->{scope};


   if( ! $keep ) {
      foreach my $f ( "access_token",
                      "expires",
                      "refresh_token",
                      "scope" ) {

         next if $self->{oauth2}->{$f} eq "";
      
         if( open FH, ">", $self->{storage_dir} . "/$f" ) {

            if( $f eq "scope" ) {
               foreach ( split /\s+/, $self->{oauth2}->{$f} ) {
                  print FH $_ . "\n";
               }
            }
            else {
               print FH $self->{oauth2}->{$f} . "\n";
            }
            
            close FH;

            chmod 0600, $self->{storage_dir} . "/$f";
         }
      }
      
      if( open FH, ">", $self->{storage_dir} . "/initial.json" ) {
         print FH $acc_token_json . "\n";
         close FH;
         
         chmod 0600, $self->{storage_dir} . "/initial.json";
      }

   }


   return( $self->{oauth2}->{access_token},
           $self->{oauth2}->{expires},
           $self->{oauth2}->{refresh_token} );
}





#----------------------------------------------------------------------
#
# NAME:  oauth2_refresh_token
#
# DESC:  
#
#
#
# ARGS:  $self    GoogleAPI Object        
#        $keep    Do not overwrite files in storage dir
#
# RETN:  Array
#        Token   - also written to the storage dir
#        Expires - also written to the storage dir
#
# HIST:  
#
#----------------------------------------------------------------------
sub oauth2_refresh_token {
   my ($self, $keep) = @_;

   my $func = "oauth2_refresh_token";

   if( $self->{oauth2}->{client_id} eq "" ) {
      $self->add_error("$func: client_id not defined");
      return undef;
   }
   
   if( $self->{oauth2}->{client_secret} eq "" ) {
      $self->add_error("$func: client_secret not defined");
      return undef;
   }
   
   if( $self->{oauth2}->{refresh_token} eq "" ) {
      $self->add_error("$func: refresh token not defined");
      return undef;
   }
   
   if( $self->{oauth2}->{redirect_uri} eq "" ) {
      $self->add_error("$func: redirect_uri not defined");
      return undef;
   }

   
   my $content =
       qq(client_id=)     . $self->{oauth2}->{client_id}       . "&" .
       qq(client_secret=) . $self->{oauth2}->{client_secret}   . "&" .
       qq(refresh_token=) . $self->{oauth2}->{refresh_token}   . "&" .
       qq(grant_type=refresh_token);


   
   my $h = HTTP::Headers->new(
      Content_Length      => length($content),
      Content_Type        => 'application/x-www-form-urlencoded' );
   
   my $req = HTTP::Request->new(POST => $self->{token_uri}, $h, $content);

   $self->add_debug("$func: HTTP REQUEST:\n" . 
                    $req->as_string . "\n") if $self->{debug_http};

   
   my $res = $self->{ua}->request($req);

   $self->add_debug("$func: HTTP RESPONSE:\n" . 
                    $res->as_string . "\n") if $self->{debug_http};


   my $acc_token_json;
   my $acc_token;
   

   if($res->is_success) {

      $acc_token_json = $res->content;

      $acc_token = $self->{json}->decode($acc_token_json);
   }
   else {
      print "ERROR: HTTP call failed refreshing access token - Exiting...\n";
      print $res->status_line, "\n";
      return undef;
   }


   if( (! exists $acc_token->{access_token} ) ||
       ($acc_token->{access_token} eq "")  ) {
      print "ERROR: Did not refresh access token - Exiting...\n";
      return undef;
   }


   $self->{oauth2}->{access_token}  = $acc_token->{access_token};
   $self->{oauth2}->{expires}       = $acc_token->{expires_in} + time;
   $self->{oauth2}->{scope}         = $acc_token->{scope};


   if( ! $keep ) {
      foreach my $f ( "access_token",
                      "expires",
                      "scope" ) {

         next if $self->{oauth2}->{$f} eq "";

         if( open FH, ">", $self->{storage_dir} . "/$f" ) {

            if( $f eq "scope" ) {
               foreach ( split /\s+/, $self->{oauth2}->{$f} ) {
                  print FH $_ . "\n";
               }
            }
            else {
               print FH $self->{oauth2}->{$f} . "\n";
            }

            close FH;

            chmod 0600, $self->{storage_dir} . "/$f";
         }
      }
      
      if( open FH, ">", $self->{storage_dir} . "/refresh.json" ) {
         print FH $acc_token_json . "\n";
         close FH;
         
         chmod 0600, $self->{storage_dir} . "/refresh.json";
      }
   }


   return( $self->{oauth2}->{access_token},
           $self->{oauth2}->{expires} );
}





#----------------------------------------------------------------------
#
# NAME:  oauth2_get_token_serviceacct
#
# DESC:  
#
#
#
# ARGS:  $self    GoogleAPI Object        
#        $keep    Do not overwrite files in storage dir
#
# RETN:  Array
#        Token   - also written to the storage dir
#        Expires - also written to the storage dir
#
# HIST:  
#
#----------------------------------------------------------------------
sub oauth2_get_token_serviceacct {
   my ($self, $keep) = @_;

   my $func = "oauth2_get_token_serviceacct";

   if( $self->{storage_type} eq "serviceacct" ) {
      if( $self->{oauth2}->{client_id} eq "" ) {
         $self->add_error("$func: client_id not defined");
         return undef;
      }
      
      if( $self->{oauth2}->{private_key} eq "" ) {
         $self->add_error("$func: private_key not defined");
         return undef;
      }
   }

   
   my $time = time;

   $self->add_debug("TIME = $time\n");


   # Setup the hashref for the assertion below
   # The client_id key for a service acct may be an ID or Email
   my $ah = { iss   => $self->{oauth2}->{client_id},
              scope => $self->{oauth2}->{scope},
              aud   => $self->{token_uri},
              exp   => $time + 3600,
              iat   => $time };

   # Check the serviceacct_subid for which to use - client_id or client_email
   if( exists $self->{serviceacct_useid} &&
       $self->{serviceacct_useid} eq "email" ) {
      $ah->{iss} = $self->{oauth2}->{client_email};
   }
   
   # Add the 'sub' key if a user email has been provided
   if( exists $self->{serviceacct_sub} && $self->{serviceacct_sub} ne "" ) {
      $ah->{sub} = $self->{serviceacct_sub};
   }


   my $res = $self->{ua}->post
       ( $self->{token_uri},
         { grant_type => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
           assertion  =>
               JSON::WebToken->encode( $ah,
                                       $self->{oauth2}->{private_key},
                                       'RS256', {typ => 'JWT'} )
         }
       );

   
   $self->add_debug("$func: HTTP RESPONSE:\n" . 
                    $res->as_string . "\n") if $self->{debug_http};


   my $acc_token_json;
   my $acc_token;
   

   if($res->is_success) {

      $acc_token_json = $res->content;

      $acc_token = $self->{json}->decode($acc_token_json);
   }
   else {
      print "ERROR: HTTP call failed getting serviceacct token - Exiting...\n";
      print $res->status_line, "\n";
      return undef;
   }


   if( (! exists $acc_token->{access_token} ) ||
       ($acc_token->{access_token} eq "")  ) {
      print "ERROR: Did not get serviceacct access token - Exiting...\n";
      return undef;
   }


   $self->{oauth2}->{access_token}  = $acc_token->{access_token};
   $self->{oauth2}->{expires}       = $acc_token->{expires_in} + $time;

   $self->add_debug("EXPIRES IN = " . $acc_token->{expires_in} . "\n");

   
   if( ! $keep ) {

      my $subname = $self->{serviceacct_sub} || "default";

      foreach my $f ( "access_token", "expires" ) {
         next if $self->{oauth2}->{$f} eq "";
         
         if( open FH, ">", $self->{storage_dir} . "/$subname" . "_" . $f ) {
            print FH $self->{oauth2}->{$f} . "\n";
         }
         
         close FH;

         chmod 0600, $self->{storage_dir} . "/$subname" . "_" . $f;
      }
      
      if( open FH, ">", $self->{storage_dir} . "/$subname.json" ) {
         print FH $acc_token_json . "\n";
         close FH;

         chmod 0600, $self->{storage_dir} . "/$subname.json";
      }
   }


   return( $self->{oauth2}->{access_token},
           $self->{oauth2}->{expires} );
}





#----------------------------------------------------------------------
#
# NAME:  oauth2_check_token
#
# DESC:  Check the access token to see if it is expired
#        Refresh the token if expired
#
#
# ARGS:  $self    GoogleAPI Object
#
# RETN:  Return Code - 0 = No need to refresh or refreshed OK
#                      1 = Tried to refresh but had problem
#
# HIST:  
#
#----------------------------------------------------------------------
sub oauth2_check_token {
   my ($self) = @_;

   my $func = "GoogleAPI::oauth2_check_token";
   
   # Determine how long we have been using the current token
   my $d = time - $self->{oauth2}->{expires};

   $self->add_debug("$func: time diff = $d");
   $self->add_debug("$func: expires   = " . $self->{oauth2}->{expires});

   my $rc = 0;

   # Factor in a 30 second buffer    
   if( $d > 30 ) {
      my @r;

      if( $self->{storage_type} eq "user" ) {
         @r = $self->oauth2_refresh_token();
      }
      elsif( $self->{storage_type} eq "serviceacct" ) {
         @r = $self->oauth2_get_token_serviceacct();
      }
      
      $self->add_debug("$func: TOKEN    = $r[0]");
      $self->add_debug("$func: EXPIRES  = $r[1]");      

      $rc = 1 if ! $r[0] || ! $r[1];
   }
       
   return $rc;
}


1;
