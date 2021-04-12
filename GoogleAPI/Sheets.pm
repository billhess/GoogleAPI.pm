#======================================================================
#
# NAME:  GoogleAPI::Sheets.pm
#
# DESC:  Google Sheets
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
package GoogleAPI::Sheets;

use strict;

use Data::Dumper;
use File::Basename;
use HTTP::Request::Common qw(GET POST PUT);
use JSON;
use LWP::UserAgent;
use MIME::Base64;
use Time::Local;
use URI::Escape;

#use GoogleAPI::Sheets::Cell;
#use GoogleAPI::Sheets::Row;
#use GoogleAPI::Sheets::Sheet;
use GoogleAPI::Sheets::Spreadsheet;





1;
