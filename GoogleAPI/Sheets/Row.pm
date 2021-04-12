#======================================================================
#
# NAME:  GoogleAPI::Sheets::Row.pm
#
# DESC:  Google Sheets Spreadsheet Row
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
package GoogleAPI::Sheets::Row;



#----------------------------------------------------------------------
#
# NAME:  new
#
# DESC:  Bless a row data hash
#
#        https://sheets.googleapis.com/v4/spreadsheets/{spreadsheetId}
#
#
#
#
# ARGS:  self  - GoogleAPI::Sheets::Row object
#        row   - ref to a row hash in a Sheet object  
#
# RETN:  
#
# HIST:  
#
#----------------------------------------------------------------------
sub new {
   my ($self, $row) = @_;

   my $func = "GoogleAPI::Sheets::Row::new";

   #------------------------------------------------------------
   # class name - GoogleAPI::Sheets::Row->new();
   #------------------------------------------------------------
   if($self eq 'GoogleAPI::Sheets::Row') {
      if($row) {
         return bless $row, "GoogleAPI::Sheets::Row";
      }
      else {
         print STDERR 
             "$func: ERROR: Invalid argument passed\n";
         return undef;
      }
   }
   else {
      print STDERR 
          "$func: ERROR: Invalid argument passed\n";
      return undef; 
   }
}


#----------------------------------------------------------------------
#
# NAME:  get_cell
#
# DESC:  Get a GoogleAPI::Sheets::Cell object for a specific cell in
#        a Sheet row
#
# ARGS:  self - GoogleAPI::Sheets::Row object
#        n    - cell number (starting at zero)
#
#
# RETN:  GoogleAPI::Sheets::Cell
#
# HIST:  031119  Created
#
#----------------------------------------------------------------------
sub get_cell {
   my ($self, $n) = @_;

   my $func = "GoogleAPI::Sheets::Row::get_cell";

   # Row object expected
   if(ref $self ne "GoogleAPI::Sheets::Row") {
      return undef
   }
   # No cell nunber specified
   elsif($n eq '') {
      print "$func: ERROR: Cell number is required\n";
      return undef;
   }
   # Non-whole number cell requested
   elsif($n !~ /^\d+$/) {
      print "$func: ERROR: Invalid cell number '$n'\n";
      return undef;
   }
   # No 'values' hash key
   elsif(! exists $self->{values}) {
      return undef;
   }
   # Cell number is too high
#   elsif(($n + 1) > (scalar @{$self->{values}})) {
#      return undef;
#   }

   # Bless hash if not already done
   if(! defined $self->{values}->[$n]) {
      $self->{values}->[$n] = bless { }, "GoogleAPI::Sheets::Cell";
   }
   elsif(ref $self->{values}->[$n] ne "GoogleAPI::Sheets::Cell") {
      $self->{values}->[$n] =
          bless $self->{values}->[$n], "GoogleAPI::Sheets::Cell";
   }

   return $self->{values}->[$n];
}


#----------------------------------------------------------------------
#
# NAME:  count_cols
#
# DESC:  Ge the count of columns/cells in a row
#
# ARGS:  self - GoogleAPI::Sheets::Row object
#
#
# RETN:  (column count)
#
# HIST:  031119  Created
#
#----------------------------------------------------------------------
sub count_cols {
   my ($self) = @_;

   my $func = "GoogleAPI::Sheets::Row::count_cols";

   # Row object expected
   if(ref $self ne "GoogleAPI::Sheets::Row") {
      return undef
   }
   # No 'values' hash key
   elsif(! exists $self->{values}) {
      return undef;
   }

   my $count = 0;

   if(ref $self->{values} eq 'ARRAY') {
      $count = scalar @{$self->{values}};
   }

   return $count;
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
