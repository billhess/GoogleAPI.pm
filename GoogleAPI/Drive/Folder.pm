#======================================================================
#
# NAME:  GoogleAPI::Drive::Folder.pm
#
# DESC:  Google Drive Folder
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
package GoogleAPI::Drive::Folder;

use strict;

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
# DESC:  Create a new GoogleAPI::Drive::Folder object
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
      return bless $f, 'GoogleAPI::Drive::Folder';
   }
   else {
      return undef;
   }
}




1;

