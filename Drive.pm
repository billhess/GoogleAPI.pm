#======================================================================
#
# NAME:  GoogleAPI::Drive.pm
#
# DESC:  Google Drive
#
#        https://developers.google.com/drive/
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
package GoogleAPI::Drive;

use strict;

use Data::Dumper;
use File::Basename;
use HTTP::Request::Common qw(GET POST PUT);
use JSON;
use LWP::UserAgent;
use MIME::Base64;
use Time::Local;
use URI::Escape;

use GoogleAPI::Drive::FileList;
use GoogleAPI::Drive::File;
use GoogleAPI::Drive::Folder;
use GoogleAPI::Drive::SharedDriveList;
use GoogleAPI::Drive::SharedDrive;
use GoogleAPI::Drive::TeamDriveList;
use GoogleAPI::Drive::TeamDrive;



#----------------------------------------------------------------------
#
# NAME:  utc_to_local
#
# DESC:  Convert UTC timestamp to local timestamp
#
#        YYYY-MM-DDThh:mm:ss[.uuu]Z -> YYYY-MM-DD hh:mm:ss
#
# ARGS:  UTC ISO timestamp
#
# RETN:  timestamp
#
# HIST:  20190529  Created  
#
#----------------------------------------------------------------------
sub utc_to_local {
   my ($utc) = @_;

   if($utc =~ /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(\.\d+)?Z$/) {
      my @t = localtime timegm($6, $5, $4, $3, $2 - 1, $1 - 1900);

      return sprintf "%04d-%02d-%02d %02d:%02d:%02d",
          $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1], $t[0];
   }
   else {
      return $utc;
   }
}


1;
