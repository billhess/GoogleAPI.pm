#======================================================================
#
# NAME:  GoogleAPI::Drive::TeamDrive.pm
#
# DESC:  Google Drive TeamDrive
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
package GoogleAPI::Drive::TeamDrive;

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
# DESC:  Create a new GoogleAPI::Drive::TeamDrive object
#
# ARGS:  h1 - self
#        h2 - GoogleAPI object
#        h3 - parameter hash
#
# RETN:  TeamDrive object
#
# HIST:  05232019  Replaced original new()
#
#----------------------------------------------------------------------
sub new {
   my ($h1, $h2, $h3) = @_;

   my $func = "GoogleAPI::Drive::TeamDrive::new";

   my $g = undef;
   my $p = undef;

   #------------------------------------------------------------
   # class name - GoogleAPI::Drive::TeamDrive->new();
   #------------------------------------------------------------
   if($h1 eq 'GoogleAPI::Drive::TeamDrive') {
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
   

   # Create object
   my $h;
   if(ref $p eq "HASH" && exists $p->{id} && defined $p->{id}) {
      $h = bless $p, 'GoogleAPI::Drive::TeamDrive';
      $h->{g} = $g;
   }
   
   return $h;
}



sub new_hold {
   my ( $td ) = @_;
   
   if( (ref $td eq "HASH") && (exists $td->{id}) ) {      
      return bless $td, 'GoogleAPI::Drive::TeamDrive';
   }
   else {
      return undef;
   }
}



#----------------------------------------------------------------------
#
# NAME:  get
#
# DESC:  Find a Google Team Drive by name
#
# ARGS:  self
#        h2   - GoogleAPI object
#        name - Team Drive name
#
# RETN:  TeamDrive object
#
# HIST:  05232019  Created
#
#----------------------------------------------------------------------
sub get {
   my ($h1, $h2, $name) = @_;

   my $func = "GoogleAPI::Drive::TeamDrive::get";

   my $g = undef;
   my $p = undef;

   #------------------------------------------------------------
   # class name - GoogleAPI::Drive::TeamDrive->get();
   #------------------------------------------------------------
   if($h1 eq 'GoogleAPI::Drive::TeamDrive') {
      $g = $h2 if ref $h2 eq 'GoogleAPI';
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


   #----------------------------------------------------------------------
   # Look for the Team Drive
   #
   # It is required to have useDomainAdminAccess=true
   # when using the query on team drives according to
   # https://developers.google.com/drive/api/v3/search-parameters#fn1
   #----------------------------------------------------------------------
   
   my $p2  = { q => qq(name="$name"),
               useDomainAdminAccess => 'true' };
   
   my $tdlist = GoogleAPI::Drive::TeamDriveList->new( $g, $p2 );
   
   # Did query fail?
   if(! $tdlist) {
      $g->add_error("Team Drive '$name' not found");
      return undef;
   }
   
   
   $g->add_debug(Dumper($tdlist) . "\n") if $g->{debug};
   
   if(! scalar @{$tdlist->{teamdrives}}) {
      $g->add_error("Team Drive '$name' not found");
      return undef;
   }
   
   
   # Return the Team Drive object 
   return $tdlist->{teamdrives}->[0];
}




#----------------------------------------------------------------------
#
# NAME:  walk_path
#
# DESC:  Traverse a folder path to reach the lowest-level folder
#
#        Ex.: path = /some/folder/foo/bar
#
#        If the entire path is found, then the GoogleAPI::Drive::Folder
#        object pointing to 'bar' is returned.  Else null is returned.
#
# ARGS:  self      - TeamDrive object
#        path      - folder path delimited by slashes
#
# RETN:  blessed object for final folder in path
#        (or null if path not found)
#
# HIST:  05232019
#
#----------------------------------------------------------------------
sub walk_path {
   my ( $self, $path ) = @_;

   my $parent_id = $self->{id};
   my $g         = $self->{g};
   
   if($path ne '') {
      # Strip off leading '/' if present
      $path =~ s/^\/+//;
      
      my @folder_list = split /\//, $path;

      for my $folder (@folder_list) {
         $g->add_debug("  Looking for '$folder'") if $g->{debug};

         my $flist =  GoogleAPI::Drive::FileList->new
             ( $g, { corpora               => 'teamDrive',
                     #pageSize              => 100,
                     teamDriveId           => $self->{id},
                     supportsTeamDrives    => 'true',
                     includeTeamDriveItems => 'true',
                     q =>
                         qq(mimeType="application/vnd.google-apps.folder" ) .
                         qq(and "$parent_id" in parents ) .
                         qq(and name = "$folder") }  );

         if(! $flist) {
            $g->add_error("Error occurred querying for path $path");
            $parent_id = undef;
            last;
         }
         elsif(! scalar @{$flist->{folders}}) {
            $g->add_error("Path '$path' not found in $self->{name}");
            $parent_id = undef;
            last;
         }
         else {
            $parent_id = $flist->{folders}->[0]->{id};
         }
      }
   }

   $g->add_debug("  Final Parent ID = '$parent_id'") if $g->{debug};


   
   if( $parent_id && ($parent_id ne $self->{id}) ) {      
      return bless { id => $parent_id }, 'GoogleAPI::Drive::Folder';
   }
   else {
      return undef;
   }
}


1;

