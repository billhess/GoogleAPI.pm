#======================================================================
#
# NAME:  GoogleAPI::Sheets::Cell.pm
#
# DESC:  Google Sheets Spreadsheet Cell
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
package GoogleAPI::Sheets::Cell;



#----------------------------------------------------------------------
#
# NAME:  new
#
# DESC:  Bless a cell data hash
#
#        https://sheets.googleapis.com/v4/spreadsheets/{spreadsheetId}
#
#
#
#
# ARGS:  self  - GoogleAPI::Sheets::Cell object
#        cell   - ref to a row hash in a Sheet object  
#
# RETN:  
#
# HIST:  
#
#----------------------------------------------------------------------
sub new {
   my ($self, $cell) = @_;

   my $func = "GoogleAPI::Sheets::Cell::new";

   #------------------------------------------------------------
   # class name - GoogleAPI::Sheets::Cell->new();
   #------------------------------------------------------------
   if($self eq 'GoogleAPI::Sheets::Cell') {
      if($cell) {
         # $cell is a hash with multiple keys

         return bless $cell, "GoogleAPI::Sheets::Cell";
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
# NAME:  get_value
#
# DESC:  Extract the value stored in a Sheets cell
#
# ARGS:  self - GoogleAPI::Sheets::Cell object
#
#
# RETN:  <value>
#
# HIST:  031119  Created
#
#----------------------------------------------------------------------
sub get_value {
   my ($self) = @_;

   my $func = "GoogleAPI::Sheets::Cell::get_value";

   # Cell object expected
   if(ref $self ne "GoogleAPI::Sheets::Cell") {
      return undef
   }

   my $value = undef;

   if(exists $self->{userEnteredValue}) {
      if(exists $self->{userEnteredValue}->{stringValue}) {
         $value = $self->{userEnteredValue}->{stringValue};
      }
      elsif(exists $self->{userEnteredValue}->{numberValue}) {
         $value = $self->{userEnteredValue}->{numberValue};
      }
   }

   if(! defined $value) {
      if(exists $self->{effectiveValue}) {
         if(exists $self->{effectiveValue}->{stringValue}) {
            $value = $self->{effectiveValue}->{stringValue};
         }
         elsif(exists $self->{effectiveValue}->{numberValue}) {
            $value = $self->{effectiveValue}->{numberValue};
         }
      }
   }

   
   return $value;
}




#----------------------------------------------------------------------
#
# NAME:  get_formattedValue
#
# DESC:  Extract the FORMATTED value stored in a Sheets cell
#
# ARGS:  self - GoogleAPI::Sheets::Cell object
#
#
# RETN:  <value>
#
# HIST:  031119  Created
#
#----------------------------------------------------------------------
sub get_formattedValue {
   my ($self) = @_;

   my $func = "GoogleAPI::Sheets::Cell::get_formattedValue";

   # Cell object expected
   if(ref $self ne "GoogleAPI::Sheets::Cell") {
      return undef
   }

   my $value = undef;

   if(exists $self->{formattedValue}) {
      $value = $self->{formattedValue};
   }
   
   return $value;
}




#----------------------------------------------------------------------
#
# NAME:  set_value
#
# DESC:  Set the value in a cell
#
# ARGS:  self - GoogleAPI::Sheets::Cell object
#        vtype - value type: ue = userEnteredValue
#                            ef = effectiveValue
#                            fo = formulaValue
#        dtype - data type:  n  = numberValue
#                            s  = stringValue
#        value - the number or string value
#
# RETN:  
#
# HIST:  031119  Created
#
#----------------------------------------------------------------------
sub set_value {
   my ($self, $vtype, $dtype, $value) = @_;

   my $func = "GoogleAPI::Sheets::Cell::set_value";

   # Cell object expected
   if(ref $self ne "GoogleAPI::Sheets::Cell") {
      return undef;
   }

   if($vtype !~ /^(ue|ef|fo)$/i) {
      $vtype = 'ue';
   }

   if($dtype !~ /[ns]/i) {
      $dtype = 's';
   }

   my $dhash;
   if(uc $dtype eq 'N') {
      $dhash = { numberValue => $value };
   }
   else {
      $dhash = { stringValue => $value };
   }

   # Remove old values
   for (qw(userEnteredValue EffectiveValue FormulaValue)) {
      delete $self->{$_};
   }
   
   if(uc $vtype eq 'UE') {
      $self->{userEnteredValue} = $dhash;
   }
   elsif(uc $vtype eq 'EF') {
      $self->{EffectiveValue} = $dhash;
   }
   elsif(uc $vtype eq 'FO') {
      $self->{FormulaValue} = $dhash;
   }

   return $self;
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



