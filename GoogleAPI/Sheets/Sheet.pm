#======================================================================
#
# NAME:  GoogleAPI::Sheets::Sheet.pm
#
# DESC:  Google Sheets Spreadsheet Sheet
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
package GoogleAPI::Sheets::Sheet;


#----------------------------------------------------------------------
#
# NAME:  new
#
# DESC:  Bless a sheet data hash
#
#        https://sheets.googleapis.com/v4/spreadsheets/{spreadsheetId}
#
#
#
#
# ARGS:  self  - GoogleAPI::Sheets::Sheet object
#        sheet - ref to a sheet hash in a Spreadsheet object  
#
# RETN:  
#
# HIST:  
#
#----------------------------------------------------------------------
sub new {
   my ($self, $sheet) = @_;

   my $func = "GoogleAPI::Sheets::Sheet::new";

   #------------------------------------------------------------
   # class name - GoogleAPI::Sheets::Sheet->new();
   #------------------------------------------------------------
   if($self eq 'GoogleAPI::Sheets::Sheet') {
      if($sheet) {
         # Add a key for the rows (should already have 'data' and 'properties')
         $sheet->{rows} = [];
         return bless $sheet, "GoogleAPI::Sheets::Sheet";
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
# NAME:  get_row
#
# DESC:  Get a GoogleAPI::Sheets::Row object for a specific row in
#        a Sheet
#
# ARGS:  self - GoogleAPI::Sheets::Sheet object
#        n    - row number (starting at zero)
#
#
# RETN:  GoogleAPI::Sheets::Row
#
# HIST:  031119  Created
#
#----------------------------------------------------------------------
sub get_row {
   my ($self, $n) = @_;

   my $func = "GoogleAPI::Sheets::Sheet::get_row";

   # Sheet object expected
   if(ref $self ne "GoogleAPI::Sheets::Sheet") {
      return undef
   }
   # No row nunber specified
   elsif($n eq '') {
      print "$func: ERROR: Row number is required\n";
      return undef;
   }
   # Non-whole number row requested
   elsif($n !~ /^\d+$/) {
      print "$func: ERROR: Invalid row number '$n'\n";
      return undef;
   }
   # No 'data' hash key in Sheet object
   elsif(! exists $self->{data}) {
      return undef;
   }
   # No 'rowdata' hash key in data array
   elsif(! exists $self->{data}->[0]->{rowData}) {
      return undef;
   }
   # Row number is too high
   elsif(($n + 1) > (scalar @{$self->{data}->[0]->{rowData}})) {
      return undef;
   }

   # Bless hash if not already done
   if(! defined $self->{data}->[0]->{rowData}->[$n]) {
      $self->{data}->[0]->{rowData}->[$n] =
          bless { }, "GoogleAPI::Sheets::Row";
   }
   elsif(ref $self->{data}->[0]->{rowData}->[$n] ne "GoogleAPI::Sheets::Row") {
      $self->{data}->[0]->{rowData}->[$n] =
          bless $self->{data}->[0]->{rowData}->[$n], "GoogleAPI::Sheets::Row";
   }

   return $self->{data}->[0]->{rowData}->[$n];
}




#----------------------------------------------------------------------
#
# NAME:  count_rows
#
# DESC:  Get the count of rows in a sheet
#
# ARGS:  self - GoogleAPI::Sheets::Sheet object
#
# RETN:  (row count)
#
# HIST:  031119  Created
#
#----------------------------------------------------------------------
sub count_rows {
   my ($self) = @_;

   my $func = "GoogleAPI::Sheets::Sheet::count_rows";

   # Sheet object expected
   if(ref $self ne "GoogleAPI::Sheets::Sheet") {
      return undef
   }

   my $count = 0;

   if(ref $self->{data}->[0]->{rowData} eq 'ARRAY') {
      $count = scalar @{$self->{data}->[0]->{rowData}};
   }

   return $count;
}




#----------------------------------------------------------------------
#
# NAME:  rows
#
# DESC:  Get a reference to the array of data rows in a sheet
#
# ARGS:  self - GoogleAPI::Sheets::Sheet object
#
# RETN:  array ref
#
# HIST:  032019  Created
#
#----------------------------------------------------------------------
sub rows {
   my ($self) = @_;

   my $func = "GoogleAPI::Sheets::Sheet::rows";

   # Sheet object expected
   if(ref $self ne "GoogleAPI::Sheets::Sheet") {
      return undef
   }

   if(exists $self->{data}->[0]->{rowData} &&
      (ref $self->{data}->[0]->{rowData} eq 'ARRAY')) {
      return $self->{data}->[0]->{rowData};
   }
   else {
      return undef;
   }
}




#----------------------------------------------------------------------
#
# NAME:  add_row
#
# DESC:  Add a new row after all existing rows on a sheet
#
# ARGS:  self - GoogleAPI::Sheets::Sheet object
#        num  - number of rows to add (assume 1 if not set)
#
# RETN:  first new row number
#
#        Example: If existing sheet has rows 0-9, and we add 3 now,
#                 we will return '10', which is the first new row
#                 number
#
# HIST:  032019  Created
#
#----------------------------------------------------------------------
sub add_row {
   my ($self, $num) = @_;

   my $func = "GoogleAPI::Sheets::Sheet::add_row";

   # Sheet object expected
   if(ref $self ne "GoogleAPI::Sheets::Sheet") {
      return undef
   }

   
   my $count = 0;

   if(ref $self->rows() eq 'ARRAY') {
      $count = scalar @{$self->rows()};

      # Add row(s)
      for (1..$num) {
         push @{$self->rows()},
             bless { values => [ ] }, "GoogleAPI::Sheets::Row";
      }
   }

   return $count;
}




#----------------------------------------------------------------------
#
# NAME:  rename
#
# DESC:  Rename a Sheet in a Spreadsheet (i.e. change Sheet title)
#
# ARGS:  self   - GoogleAPI::Sheets::Sheet object
#        g      - GoogleAPI object
#        parent - parent GoogleAPI::Sheets::Spreadsheet object
#        name   - new name (title) for sheet
#
#
# RETN:  
#
# HIST:  041119  Created
#
#----------------------------------------------------------------------
sub rename {
   my ($self, $g, $parent, $name) = @_;

   my $func = "GoogleAPI::Sheets::Sheet::rename";

   # Sheet object expected
   if(ref $self ne "GoogleAPI::Sheets::Sheet") {
      return undef
   }
   # New name not specified
   elsif($name eq '') {
      print "$func: ERROR: New sheet name is required\n";
      return undef;
   }

   my $id = $self->{properties}->{sheetId};
   
   my $req =
   { updateSheetProperties => { properties => { title   => $name,
                                                sheetId => $id },
                                fields     => 'title' } };

   my $res = $parent->batch_update( $g, [ $req ]);
   
   return $res;
}





#----------------------------------------------------------------------
#
# NAME:  textFormat
#
# DESC:  Generate request for text formatting on a range of cells
#
# ARGS:  self     - sheet object
#        startrow - starting row of cell range
#        endrow   - ending row
#        startcol - starting column
#        endcol   - ending column
#        other    - optional - hash of other args
#
# RETN:  batchUpdate request
#
# HIST:  041519  Created
#
#----------------------------------------------------------------------
sub textFormat {
   my ($self, $startrow, $endrow, $startcol, $endcol, $other) = @_;

   my $tf  = { };

   my $req = 
   { repeatCell =>  { range  => { sheetId          =>
                                      $self->{properties}->{sheetId},
                                  startRowIndex    => $startrow,
                                  endRowIndex      => $endrow,
                                  startColumnIndex => $startcol,
                                  endColumnIndex   => $endcol     },
                      
                      cell   => { userEnteredFormat => { textFormat => $tf } },
                      fields => "userEnteredFormat(textFormat)"
     }
   };

   if($other && (ref $other eq 'HASH')) {

      if(exists $other->{foregroundColor}) {
         if(ref $other->{foregroundColor} eq 'HASH') {
            $tf->{foregroundColor} = $other->{foregroundColor};
         }
      }
      
      if(exists $other->{fontFamily}) {
         if($other->{fontFamily} ne '') {
            $tf->{fontFamily} = $other->{fontFamily};
         }
      }
      
      if(exists $other->{fontSize}) {
         if($other->{fontSize} ne '') {
            $tf->{fontSize} = $other->{fontSize};
         }
      }


      foreach my $style ( qw(bold italic strikethrough underline) ) {
         if(exists $other->{$style}) {
            if($other->{$style} =~ /^(0|false)$/i) {
               $tf->{$style} = 'false';
            }
            elsif($other->{$style} =~ /^(1|true)$/i) {
               $tf->{$style} = 'true';
            }
         }
      }
   }
         
   return $req;
}




#----------------------------------------------------------------------
#
# NAME:  numberFormat
#
# DESC:  Generate request for number formatting on a range of cells
#
# ARGS:  self     - sheet object
#        startrow - starting row of cell range
#        endrow   - ending row
#        startcol - starting column
#        endcol   - ending column
#        pattern  - optional (default = "#,##0.00")
#
# RETN:  batchUpdate request
#
# HIST:  090919  Created
#
#----------------------------------------------------------------------
sub numberFormat {
   my ($self, $startrow, $endrow, $startcol, $endcol, $pattern) = @_;

   $pattern = "#,##0.00" if $pattern eq '';

   my $req = 
   { repeatCell =>  { 'range'  => { 'sheetId'          =>
                                        $self->{properties}->{sheetId},
                                        'startRowIndex'    => $startrow,
                                        'endRowIndex'      => $endrow,
                                        'startColumnIndex' => $startcol,
                                        'endColumnIndex'   => $endcol },
                          
                          'cell'   => { 'userEnteredFormat' =>
                                        { 'numberFormat' =>
                                          { 'type'    => "NUMBER",
                                            'pattern' => $pattern
                                          }
                                        } 
                      },
                      
                      'fields' => "userEnteredFormat.numberFormat"
     }
   };
   

   return $req;
}



#----------------------------------------------------------------------
#
# NAME:  dateFormat
#
# DESC:  Generate request for date formatting on a range of cells
#
# ARGS:  self     - sheet object
#        startrow - starting row of cell range
#        endrow   - ending row
#        startcol - starting column
#        endcol   - ending column
#        pattern  - optional (default = "yyyymmdd")
#
# RETN:  batchUpdate request
#
# HIST:  090919  Created
#
#----------------------------------------------------------------------
sub dateFormat {
   my ($self, $startrow, $endrow, $startcol, $endcol, $pattern) = @_;

   $pattern = "yyyymmdd" if $pattern eq '';

   my $req = 
   { repeatCell =>  { 'range'  => { 'sheetId'          =>
                                        $self->{properties}->{sheetId},
                                        'startRowIndex'    => $startrow,
                                        'endRowIndex'      => $endrow,
                                        'startColumnIndex' => $startcol,
                                        'endColumnIndex'   => $endcol },
                          
                          'cell'   => { 'userEnteredFormat' =>
                                        { 'numberFormat' =>
                                          { 'type'    => "DATE",
                                            'pattern' => $pattern
                                          }
                                        } 
                      },
                      
                      'fields' => "userEnteredFormat.numberFormat"
     }
   };
   

   return $req;
}



#----------------------------------------------------------------------
#
# NAME:  bold
#
# DESC:  Generate request for bold text formatting on a range of cells
#
# ARGS:  self     - sheet object
#        startrow - starting row of cell range
#        endrow   - ending row
#        startcol - starting column
#        endcol   - ending column
#        other    - optional - hash of other args
#
# RETN:  batchUpdate request
#
# HIST:  041519  Created
#
#----------------------------------------------------------------------
sub bold {
   my ($self, $startrow, $endrow, $startcol, $endcol, $other) = @_;

   
   my $req = 
   { repeatCell =>  { range => { sheetId          =>
                                     $self->{properties}->{sheetId},
                                 startRowIndex    => $startrow,
                                 endRowIndex      => $endrow,
                                 startColumnIndex => $startcol,
                                 endColumnIndex   => $endcol},
                      
                      cell => { userEnteredFormat =>
                                { textFormat =>
                                  { bold => 'true' }
                                }
                      },
                      
                      fields => "userEnteredFormat(textFormat)"
     }
   };

   if($other && (ref $other eq 'HASH')) {
      if(exists $other->{bold}) {
         if($other->{bold} =~ /^(0|false)$/i) {
            $req->{repeatCell}->{cell}->{userEnteredFormat}
            ->{textFormat}->{bold} = 'false';
         }
      }

      if(exists $other->{font_size}) {
         if($other->{font_size} ne '') {
            $req->{repeatCell}->{cell}->{userEnteredFormat}
            ->{textFormat}->{fontSize} = $other->{font_size};
         }
      }

      if(exists $other->{font_color}) {
         if(ref $other->{font_color} eq 'HASH') {
            $req->{repeatCell}->{cell}->{userEnteredFormat}
            ->{textFormat}->{foregroundColor} = $other->{font_color};
         }
      }
   }
         
   return $req;
}




#----------------------------------------------------------------------
#
# NAME:  italic
#
# DESC:  Generate request for italic text formatting on a range of cells
#
# ARGS:  self     - sheet object
#        startrow - starting row of cell range
#        endrow   - ending row
#        startcol - starting column
#        endcol   - ending column
#        other    - optional - hash of other args
#
# RETN:  batchUpdate request
#
# HIST:  041519  Created
#
#----------------------------------------------------------------------
sub italic {
   my ($self, $startrow, $endrow, $startcol, $endcol, $other) = @_;

   
   my $req = 
   { repeatCell =>  { range => { sheetId          =>
                                     $self->{properties}->{sheetId},
                                 startRowIndex    => $startrow,
                                 endRowIndex      => $endrow,
                                 startColumnIndex => $startcol,
                                 endColumnIndex   => $endcol},
                      
                      cell => { userEnteredFormat =>
                                { textFormat =>
                                  { italic => 'true' }
                                }
                      },
                      
                      fields => "userEnteredFormat(textFormat)"
     }
   };

   if($other && (ref $other eq 'HASH')) {
      if(exists $other->{bold}) {
         if($other->{bold} =~ /^(0|false)$/i) {
            $req->{repeatCell}->{cell}->{userEnteredFormat}
            ->{textFormat}->{bold} = 'false';
         }
      }

      if(exists $other->{font_size}) {
         if($other->{font_size} ne '') {
            $req->{repeatCell}->{cell}->{userEnteredFormat}
            ->{textFormat}->{fontSize} = $other->{font_size};
         }
      }

      if(exists $other->{font_color}) {
         if(ref $other->{font_color} eq 'HASH') {
            $req->{repeatCell}->{cell}->{userEnteredFormat}
            ->{textFormat}->{foregroundColor} = $other->{font_color};
         }
      }
   }
         
   return $req;
}



#----------------------------------------------------------------------
#
# NAME:  wrap
#
# DESC:  Generate request for text wrapping on a range of cells
#
# ARGS:  self     - sheet object
#        startrow - starting row of cell range
#        endrow   - ending row
#        startcol - starting column
#        endcol   - ending column
#
# RETN:  batchUpdate request
#
# HIST:  060619  Created
#
#----------------------------------------------------------------------
sub wrap {
   my ($self, $startrow, $endrow, $startcol, $endcol) = @_;

   
   my $req = 
   { repeatCell =>  { range => { sheetId          =>
                                     $self->{properties}->{sheetId},
                                 startRowIndex    => $startrow,
                                 endRowIndex      => $endrow,
                                 startColumnIndex => $startcol,
                                 endColumnIndex   => $endcol},
                      
                      cell  => { userEnteredFormat =>
                                 { wrapStrategy => "WRAP" },
                                 #effectiveFormat =>
                                 #{ wrapStrategy => "WRAP" },
                      },

                      fields => "userEnteredFormat(wrapStrategy)"
     }
   };

   return $req;
}




#----------------------------------------------------------------------
#
# NAME:  note
#
# DESC:  Generate request for bold text formatting on a range of cells
#
# ARGS:  self     - sheet object
#        startrow - starting row of cell range
#        endrow   - ending row
#        startcol - starting column
#        endcol   - ending column
#        text     - note text
#
# RETN:  batchUpdate request
#
# HIST:  041519  Created
#
#----------------------------------------------------------------------
sub note {
   my ($self, $startrow, $endrow, $startcol, $endcol, $text) = @_;

   return
   { repeatCell =>  { range => { sheetId          =>
                                     $self->{properties}->{sheetId},
                                 startRowIndex    => $startrow,
                                 endRowIndex      => $endrow,
                                 startColumnIndex => $startcol,
                                 endColumnIndex   => $endcol},
                      
                      cell => { note => $text },
                      
                      fields => "note"
     }
   };
}




#----------------------------------------------------------------------
#
# NAME:  freeze_rows
#
# DESC:  Generate request to freeze first row(s) of a sheet
#
# ARGS:  self     - sheet object
#        rows     - number of rows to freeze
#
# RETN:  batchUpdate request
#
# HIST:  042519  Created
#
#----------------------------------------------------------------------
sub freeze_rows {
   my ($self, $rows) = @_;

   return
   { updateSheetProperties =>
     { properties => {
        sheetId        => $self->{properties}->{sheetId},
        gridProperties => {
           frozenRowCount => $rows
        }
       },
       fields => 'gridProperties.frozenRowCount'
     }
   };
}




#----------------------------------------------------------------------
#
# NAME:  bgcolor
#
# DESC:  Generate request for setting the background color on a
#        range of cells
#
# ARGS:  self     - sheet object
#        startrow - starting row of cell range
#        endrow   - ending row
#        startcol - starting column
#        endcol   - ending column
#        color    - color hash: { red   => <red value>,
#                                 green => <green value>,
#                                 blue  => <blue value> }
#
# RETN:  batchUpdate request
#
# HIST:  041519  Created
#
#----------------------------------------------------------------------
sub bgcolor {
   my ($self, $startrow, $endrow, $startcol, $endcol, $color) = @_;

   return
   { repeatCell =>  { range => { sheetId          =>
                                     $self->{properties}->{sheetId},
                                 startRowIndex    => $startrow,
                                 endRowIndex      => $endrow,
                                 startColumnIndex => $startcol,
                                 endColumnIndex   => $endcol},
                      
                      cell => { userEnteredFormat =>
                                { backgroundColor => $color },
                      },
                      
                      fields => "userEnteredFormat(backgroundColor)"
     }
   };
}




#----------------------------------------------------------------------
#
# NAME:  merge
#
# DESC:  Generate request to merge some cells
#
# ARGS:  self     - sheet object
#        startrow - starting row of cell range
#        endrow   - ending row
#        startcol - starting column
#        endcol   - ending column
#
# RETN:  batchUpdate request
#
# HIST:  041519  Created
#
#----------------------------------------------------------------------
sub merge {
   my ($self, $startrow, $endrow, $startcol, $endcol) = @_;
   
   return
   { mergeCells =>  { range     => { sheetId          =>
                                         $self->{properties}->{sheetId},
                                     startRowIndex    => $startrow,
                                     endRowIndex      => $endrow,
                                     startColumnIndex => $startcol,
                                     endColumnIndex   => $endcol},
                      
                      mergeType => "MERGE_ALL"
     }
   };
}




#----------------------------------------------------------------------
#
# NAME:  left  right  center
#
# DESC:  Generate request to horizontal align some cells
#        Convience method that calls/sets horizontalAlignment
#
# ARGS:  self     - sheet object
#        startrow - starting row of cell range
#        endrow   - ending row
#        startcol - starting column
#        endcol   - ending column
#
#
# RETN:  batchUpdate request
#
# HIST:  041519  Created
#
#----------------------------------------------------------------------
sub left {
   my ($self, $startrow, $endrow, $startcol, $endcol) = @_;

   return $self->horizontalAlignment( $startrow, $endrow,
                                      $startcol, $endcol, "LEFT" );
}


sub right {
   my ($self, $startrow, $endrow, $startcol, $endcol) = @_;

   return $self->horizontalAlignment( $startrow, $endrow,
                                      $startcol, $endcol, "RIGHT" );
}


sub center {
   my ($self, $startrow, $endrow, $startcol, $endcol) = @_;

   return $self->horizontalAlignment( $startrow, $endrow,
                                      $startcol, $endcol, "CENTER" );
}


#----------------------------------------------------------------------
#
# NAME:  horizontalAlignment
#
# DESC:  Generate request to left-align some cells
#
# ARGS:  self     - sheet object
#        startrow - starting row of cell range
#        endrow   - ending row
#        startcol - starting column
#        endcol   - ending column
#        align    - LEFT, RIGHT, CENTER
#        other    - optional - hash of other args
#
# RETN:  batchUpdate request
#
# HIST:  041519  Created
#
#----------------------------------------------------------------------
sub horizontalAlignment {
   my ($self, $startrow, $endrow, $startcol, $endcol, $align) = @_;

   my $req = 
   { repeatCell =>  { range  => { sheetId          =>
                                      $self->{properties}->{sheetId},
                                  startRowIndex    => $startrow,
                                  endRowIndex      => $endrow,
                                  startColumnIndex => $startcol,
                                  endColumnIndex   => $endcol},
                      
                      cell   => { userEnteredFormat =>
                                  { horizontalAlignment => $align },
                      },
                      
                      fields => "userEnteredFormat(horizontalAlignment)"
     }
   };


   # Remove key if it is undefined
   # This is how to format an entire column/row
   delete
       $req->{repeatCell}->{range}->{startRowIndex}    if ! defined $startrow;
   delete
       $req->{repeatCell}->{range}->{endRowIndex}      if ! defined $endrow;
   delete
       $req->{repeatCell}->{range}->{startColumnIndex} if ! defined $startcol;
   delete
       $req->{repeatCell}->{range}->{endColumnIndex}   if ! defined $endcol;


   #if($other && (ref $other eq 'HASH')) {
   #   if(exists $other->{bold}) {
   #      if($other->{bold} =~ /^(0|false)$/i) {
   #         $req->{repeatCell}->{cell}->{userEnteredFormat}
   #         ->{textFormat}->{bold} = 'false';
   #      }
   #   }
   #
   #   if(exists $other->{font_size}) {
   #      if($other->{font_size} ne '') {
   #         $req->{repeatCell}->{cell}->{userEnteredFormat}
   #         ->{textFormat}->{fontSize} = $other->{font_size};
   #      }
   #   }
   #
   #   if(exists $other->{font_color}) {
   #      if(ref $other->{font_color} eq 'HASH') {
   #         $req->{repeatCell}->{cell}->{userEnteredFormat}
   #         ->{textFormat}->{foregroundColor} = $other->{font_color};
   #      }
   #   }
   #}

   
   return $req;
}





#----------------------------------------------------------------------
#
# NAME:  protect
#
# DESC:  Generate request to protect a sheet
#
# ARGS:  self     - sheet object
#        desc     - description of protected range (optional)
#
# RETN:  batchUpdate request
#
# HIST:  041719  Created
#
#----------------------------------------------------------------------
sub protect {
   my ($self, $desc) = @_;

   $desc = "Whole sheet" if $desc  eq '';
   
   return
   { addProtectedRange =>
     { protectedRange =>
       { range =>
         { sheetId => $self->{properties}->{sheetId} },
         description => $desc }
     }
   };
}




#----------------------------------------------------------------------
#
# NAME:  set_col_width
#
# DESC:  Generate request to set the width for a range of columns
#
# ARGS:  self     - sheet object
#        startcol - starting column
#        endcol   - endig column
#        width    - widthof each column in pixels
#
# RETN:  batchUpdate request
#
# HIST:  041519  Created
#
#----------------------------------------------------------------------
sub set_col_width {
   my ($self, $startcol, $endcol, $width) = @_;

   return
   { updateDimensionProperties => {
      range      => { sheetId    => $self->{properties}->{sheetId},
                      dimension  => "COLUMNS",
                      startIndex => $startcol,
                      endIndex   => $endcol
      },
      properties => { pixelSize => $width },
      fields     => "pixelSize" 
     }
   };
}




#----------------------------------------------------------------------
#
# NAME:  auto_resize_cols
#
# DESC:  Generate request to auto-resize all columns
#
# ARGS:  self     - sheet object
#
# RETN:  batchUpdate request
#
# HIST:  041519  Created
#
#----------------------------------------------------------------------
sub auto_resize_cols {
   my ($self) = @_;

   return
   { autoResizeDimensions
         => { dimensions  => { sheetId   => $self->{properties}->{sheetId},
                               dimension => "COLUMNS" }
     }
   };
}




#----------------------------------------------------------------------
#
# NAME:  a1_convert_col
#
# DESC:  Convert a column number to a letter in A1 notation
#        Ex.:  1 -> A, 2 -> B, 26 -> Z, 27 -> AA, 28 -> AB
#
# ARGS:  num - column number (starting at 1)
#
# RETN:  a1_col - letter-based column label
#
# HIST:  041119  Created
#
#----------------------------------------------------------------------
sub a1_convert_col {
   my ($num) = @_;

   my $a1_col;

   # Only 1 - 26*26 are valid
   if($num > 0 && $num <= (26**2)) {
      my @letters = 'A'..'Z';

      # Two letters
      if($num > 26) {
         $a1_col = $letters[int($num/26) - 1] . $letters[($num % 26) - 1];
      }
      # One letter
      else {
         $a1_col = $letters[$num - 1];
      }
   }
   
   return $a1_col;
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
