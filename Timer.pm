package Util::Timer;
use Moose::Role;
use Method::Signatures::Simple;

=head2

  PACKAGE    Util::Timer
  
  PURPOSE
  
    TIME-RELATED METHODS
    
=cut

method localTime {
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime;
   
    $min = sprintf "%02d", $min;

    my $ampm = "AM";
    if ($hour > 12) 
    {
        $hour = $hour - 12;
        $ampm = "PM";
    }

    my @Days = ("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday");
    my @Months = ("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December");
    
    my $day = $Days[$wday];
    my $month = $Months[$mon];
    my $date = $mday;
    
    $year = 1900 + $year;
    if ($year eq "1900")
    {
        $year = 2000 + $year;
    }
    
    my $datetime = "$hour:$min$ampm, $date $month $year";
    return $datetime;
}

method runtime ( $start_time, $end_time ) {
  
  my $run_time = $end_time - $start_time;
  ($run_time) = $self->hoursMinsSecs($run_time);
#  $self->logNote("\nRUN TIME", $run_time);

  return $run_time;  
}

method hoursMinsSecs ( $seconds ) {
  
  my $hours = int($seconds / 3600);
  my $minutes = int( ($seconds % 3600) / 60 );
  $seconds = ( ($seconds % 3600) % 60 );

  $hours = $self->padZero($hours, 2);
  $minutes = $self->padZero($minutes, 2);
  $seconds = $self->padZero($seconds, 2);
  
  return "$hours:$minutes:$seconds";
}

method seconds ( $hoursMinsSecs ) {
  
  my $seconds = 0;
  my ($hours, $mins, $secs) = $hoursMinsSecs =~ /^([^:]+):([^:]+):([^:]+)$/;
  $seconds += $hours * 3600;
  $seconds += $mins * 60;
  $seconds += $secs;

  return $seconds;
}


method padZero ( $number, $pad ) {
  
  my $sprintf = "%0" . $pad . "d";
  $number = sprintf $sprintf, $number;

  return $number;
}

method currentTime {
  my ($sec, $min, $hour, $day_of_month, $month, $year, $weekday, $day_of_year, $isdst) = localtime;  
  
  $min = sprintf "%02d", $min;
  $day_of_month = sprintf "%02d", $day_of_month;
  $month  = $month + 1;  
  $month  = sprintf "%02d", $month; 
  $hour  = sprintf "%02d", $hour;
  $min  = sprintf "%02d", $min;
  $sec  = sprintf "%02d", $sec;  
  $year  = 1900 + $year;
  $year  =~ s/^\d{2}//;

  my $currentTime = "$year-$month-$day_of_month $hour:$min:$sec";
  
  return ($currentTime);
}

method currentTimeToMysql ( $currentTime ) {

  # CURRENT DATETIME:  06-05-13 17:52:21
  # MYSQL DATETIME:  1998-07-06 09:32:36
  my ($year) = $currentTime =~ /^(\d+)/;
  my $extra_digits = 19;
  if ( $year < 20 )  {  $extra_digits = 20;  }  
  
  return "$extra_digits$currentTime";
}

method getMysqlTime {
  $self->logNote("");
  
  my ( $seconds, $minutes, $hour, $date, $month, $year, $weekday, $yday, $isdst) = localtime();
  $self->logNote("month", $month);
  $month = $self->monthNumber($month);
  $self->logNote("month number", $month);
  
  $date = "0" . $date if length($date) == 1;
  
  my $mysqldatetime = "$year-$month-$date $hour:$minutes:$seconds";
  $self->logNote("mysqldatetime", $mysqldatetime);
    
  return $mysqldatetime;
}

# CONVERT FROM DATETIME
#
# date DATE:   Sat May 3   19:24:16 UTC 2014
# BLAST DATE:   Fri Jul 6   09:32:36 1998
# .ACE DATE:   Thu Jan 19   20:32:58 2006
# .PHD DATE:   Thu Jan 19   20:32:58 2006
# STAT DATE: Apr 16 19:39:22 2006
#
# TO MYSQL DATETIME
#
# MYSQL DATE: 1998-07-06 09:32:36
# 
method datetimeToMysql ( $datetime ) {
  #$self->logDebug("datetime", $datetime);

  my ( $month, $date, $hour, $minutes, $seconds, $timezone, $year) = $datetime =~ /^\s*\S+\s+(\S+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\w+)?\s+(\d+)\s*/;

  $self->logNote("month", $month);
  $month = $self->monthNumber($month);
  $self->logNote("month number", $month);
  
  $date = "0" . $date if length($date) == 1;
  
  my $mysqldatetime = "$year-$month-$date $hour:$minutes:$seconds";
  $self->logNote("mysqldatetime", $mysqldatetime);
    
    return $mysqldatetime;
}


# CONVERT FROM:
#
# Thu Aug 30 01:23:59 EDT 2018
#
# TO:
#
# 2018-08-30 06:23:59
#
method datetimeToGmt ( $datetime ) {
  #$self->logDebug("datetime", $datetime);
  my ( $month, $date, $hour, $minutes, $seconds, $timezone, $year) = $datetime =~ /^\s*\S+\s+(\S+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\w+)?\s+(\d+)\s*/;

  # $self->logNote("timezone", $timezone);
  # $self->logNote("month", $month);
  $month = $self->monthNumber($month);

  #### ADJUST FOR TIME ZONE
  $hour = $self->convertToGmt($hour, $timezone);
  #### IF NEGATIVE, GO BACK A DAY
  if ( $hour < 0 ) {
    $hour = 24 + $hour;
    $self->logDebug("hour", $hour);
    ($year, $month, $date) = $self->backOneDay( $year, $month, $date );
  }

  $date = "0" . $date if length($date) == 1;

  my $gmt = "$year-$month-$date $hour:$minutes:$seconds";
  $self->logNote("gmt", $gmt);
    
  return $gmt;
}

method backOneDay ( $year, $month, $date ) {
  
  $date -= 1;
  if ( $date < 1 ) {
    $month -= 1;

    if ( $month < 1 ) {
      $date = 31;
      $month = 12;
      $year -= 1;
    }
    else {
      my $monthdays = $self->daysPerMonth( $year );
      $date = $monthdays->{$month};      
    }
  }
      
  return $year, $month, $date;
}

method convertToGmt ( $hour, $timezone ) {
  # $self->logDebug("hour", $hour);
  # $self->logDebug("timezone", $timezone);
  my $timezones = $self->timeZones();
  my $difference = $timezones->{$timezone};
  # $self->logDebug("difference", $difference); 
  if ( not defined $difference ) {
    print "Timezone not recognised: $timezone\n";
    return;
  }
  my ($operation, $lag) = $difference =~ /^(\+|\−)([\d+:]+)/;
  # $self->logDebug("operation", $operation);
  # $self->logDebug("lag", $lag);
  if ( $lag =~ /^(\d+):(\d+)$/ ) {
    my $hours = $1;
    my $minutes = $2;
    $lag = $hours + ($minutes / 60);
  }

  if ( $operation eq "+" ) {
    $hour += $lag;
  }
  else {
    $hour -= $lag;
  }

  return $hour;
}

method compareGmt ( $date1, $date2 ) {
  my $datearray1 = split "-", $date1 =~ s/\s+/-/g;
  $self->logDebug("datearray1", $datearray1);

}

  # CONVERT FROM BLAST DATETIME TO MYSQL DATETIME
  # BLAST DATE: Fri Jul 6 09:32:36 1998
  # .ACE DATE: Thu Jan 19 20:32:58 2006
  # .PHD DATE: Thu Jan 19 20:32:58 2006
  # MYSQL DATE: 1998-07-06 09:32:36
  # 
    # STAT DATE: Apr 16 19:39:22 2006
method blastToMysql {    
  my $blast_datetime      =   shift;
 
    my ( $month, $date, $hour, $minutes, $seconds, $year) = $blast_datetime =~ /^\s*\S+\s+(\S+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\d+)\s*/;
   # $date = Annotation::two_digit($date);
    $month = month_number($month);
    my $mysql_datetime = "$year-$month-$date $hour:$minutes:$seconds";
    
    return $mysql_datetime;
}

method monthNumber ( $month ) {
    
    if ( $month =~ /^Jan/ ) {   return "01";    }
    elsif ( $month =~ /^Feb/ ) {   return "02";    }
    elsif ( $month =~ /^Mar/ ) {   return "03";    }
    elsif ( $month =~ /^Apr/ ) {   return "04";    }
    elsif ( $month =~ /^May/ ) {   return "05";    }
    elsif ( $month =~ /^Jun/ ) {   return "06";    }
    elsif ( $month =~ /^Jul/ ) {   return "07";    }
    elsif ( $month =~ /^Aug/ ) {   return "08";    }
    elsif ( $month =~ /^Sep/ ) {   return "09";    }
    elsif ( $month =~ /^Oct/ ) {   return "10";    }
    elsif ( $month =~ /^Nov/ ) {   return "11";    }
    return "12";
}

method statDatetimeCreated ( $filename ) {
  
  my $stat_string = `/usr/bin/stat $filename`;
  my $tokens = $self->tokeniseString($stat_string); # DATA ENTRIES ARE DELIMITED WITH " " IF THEY CONTAIN SPACES
  # 234881035 24271102 -rwxrwxrwx 1 young young 0 10000 "Apr 25 15:31:06 2006" "Jan 19 20:28:37 2006" "Jan 25 14:51:27 2006" 4096 24 0 /Users/young/FUNNYBASE/pipeline/151-158/phd_dir/151-001-A01.ab1.phd.1

  #  FORMAT: Jan 25 14:51:27 2006  
  my $stat_datetime = $$tokens[10];
  # NB: Not all fields are supported on all filesystem types. Here are the meanings of the fields:
  # 0 dev      device number of filesystem
  # 1 ino      inode number
  # 2 mode     file mode  (type and permissions)
  # 3 nlink    number of (hard) links to the file
  # 4 uid      numeric user ID of file's owner
  # 5 gid      numeric group ID of file's owner
  # 6 rdev     the device identifier (special files only)
  # 7 size     total size of file, in bytes
  # 8 atime    last access time in seconds since the epoch
  # 9 mtime    last modify time in seconds since the epoch
  #10 ctime    inode change time in seconds since the epoch (*)
  #11 blksize  preferred block size for file system I/O
  #12 blocks   actual number of blocks allocated

  return $stat_datetime;
}

method statDatetimeModified ( $filename ) {
  
  my $stat_string = `/usr/bin/stat $filename`;
  my $tokens = $self->tokeniseString($stat_string); # DATA ENTRIES ARE DELIMITED WITH " " IF THEY CONTAIN SPACES
  # 234881035 24271102 -rwxrwxrwx 1 young young 0 10000 "Apr 25 15:31:06 2006" "Jan 19 20:28:37 2006" "Jan 25 14:51:27 2006" 4096 24 0 /Users/young/FUNNYBASE/pipeline/151-158/phd_dir/151-001-A01.ab1.phd.1

  #  FORMAT: Jan 25 14:51:27 2006  
  my $stat_datetime = $$tokens[9];
  # NB: Not all fields are supported on all filesystem types. Here are the meanings of the fields:
  # 0 dev      device number of filesystem
  # 1 ino      inode number
  # 2 mode     file mode  (type and permissions)
  # 3 nlink    number of (hard) links to the file
  # 4 uid      numeric user ID of file's owner
  # 5 gid      numeric group ID of file's owner
  # 6 rdev     the device identifier (special files only)
  # 7 size     total size of file, in bytes
  # 8 atime    last access time in seconds since the epoch
  # 9 mtime    last modify time in seconds since the epoch
  #10 ctime    inode change time in seconds since the epoch (*)
  #11 blksize  preferred block size for file system I/O
  #12 blocks   actual number of blocks allocated

  return $stat_datetime;
}

method tokeniseString ( $string ) {
  chomp($string);
#  $self->logNote("STRING", $string);
    
  my $tokens;  
  my $token_counter = 0;
  while ( $string !~ /^\s*$/ )
  {
#    $self->logNote("Do quote check");
    my $token = '';
    if ( $string =~ s/^\s*"// )
    {
      while ( $string !~ /^\s*"/ and $string !~ /^\s*$/ )
      {
        $string =~ s/^\s*([^"^\s]+)//;
        ($token) .= "$1 ";
        $token_counter++;  
#        $self->logNote("Token counter (inner): $token_counter", $token);
      }
      $string =~ s/^\s*"//;
#      $self->logNote("String at end (inner)", $string);
    }
    else
    {
      $string =~ s/^\s*(\S+)\s*//;
      ($token) .= $1;
#      $self->logNote("No-quote token", $token);
    }
    
    push @$tokens, $token;
    $token_counter++;
  }
  return $tokens;
}
  
# CONVERT FROM STAT DATETIME TO MYSQL DATETIME
# STAT DATE: Apr 16 19:39:22 2006
# MYSQL DATE: 1998-07-06 09:32:36
#
# BLAST DATE: Fri Jul 6 09:32:36 1998
# .ACE DATE: Thu Jan 19 20:32:58 2006  
# .PHD DATE: Thu Jan 19 20:32:58 2006
method stattimeToMysql ( $stat_datetime ) {

  #  FORMAT: Jan 25 14:51:27 2006  
  my ( $month, $date, $time, $year) = split " ", $stat_datetime;
  my ($hour, $minutes, $seconds) = split ":", $time;
  $month = $self->monthNumber($month);
    my $mysql_datetime = "$year-$month-$date $hour:$minutes:$seconds";
    
    return $mysql_datetime;
}
  

method timeZones {
  return {
ACDT  =>  "+10:30", # Australian Central Daylight Savings Time
ACST  =>  "+09:30", # Australian Central Standard Time
ACT =>  "−05",  # Acre Time
ACT =>  "+06:30", # ASEAN Common Time – UTC+09
ACWST =>  "+08:45", # Australian Central Western Standard Time (unofficial)
ADT =>  "−03",  # Atlantic Daylight Time
AEDT  =>  "+11",  # Australian Eastern Daylight Savings Time
AEST  =>  "+10",  # Australian Eastern Standard Time
AFT =>  "+04:30", # Afghanistan Time
AKDT  =>  "−08",  # Alaska Daylight Time
AKST  =>  "−09",  # Alaska Standard Time
AMST  =>  "−03",  # Amazon Summer Time (Brazil)[1]
AMT =>  "−04",  # Amazon Time (Brazil)[2]
AMT =>  "+04",  # Armenia Time
ART =>  "−03",  # Argentina Time
AST =>  "+03",  # Arabia Standard Time
AST =>  "−04",  # Atlantic Standard Time
AWST  =>  "+08",  # Australian Western Standard Time
AZOST   =>  "+00",  # Azores Summer Time
AZOT  =>  "−01",  # Azores Standard Time
AZT =>  "+04",  # Azerbaijan Time
BDT =>  "+08",  # Brunei Time
BIOT  =>  "+06",  # British Indian Ocean Time
BIT =>  "−12",  # Baker Island Time
BOT =>  "−04",  # Bolivia Time
BRST  =>  "−02",  # Brasília Summer Time
BRT =>  "−03",  # Brasilia Time
BST =>  "+06",  # Bangladesh Standard Time
BST =>  "+11",  # Bougainville Standard Time[3]
BST =>  "+01",  # British Summer Time (British Standard Time from Feb 1968 to Oct 1971)
BTT =>  "+06",  # Bhutan Time
CAT =>  "+02",  # Central Africa Time
CCT =>  "+06:30", # Cocos Islands Time
CDT =>  "−05",  # Central Daylight Time (North America)
CDT =>  "−04",  # Cuba Daylight Time[4]
CEST  =>  "+02",  # Central European Summer Time (Cf. HAEC)
CET =>  "+01",  # Central European Time
CHADT =>  "+13:45", # Chatham Daylight Time
CHAST =>  "+12:45", # Chatham Standard Time
CHOT  =>  "+08",  # Choibalsan Standard Time
CHOST =>  "+09",  # Choibalsan Summer Time
CHST  =>  "+10",  # Chamorro Standard Time
CHUT  =>  "+10",  # Chuuk Time
CIST  =>  "−08",  # Clipperton Island Standard Time
CIT =>  "+08",  # Central Indonesia Time
CKT =>  "−10",  # Cook Island Time
CLST  =>  "−03",  # Chile Summer Time
CLT =>  "−04",  # Chile Standard Time
COST  =>  "−04",  # Colombia Summer Time
COT =>  "−05",  # Colombia Time
CST =>  "−06",  # Central Standard Time (North America)
CST =>  "+08",  # China Standard Time
CST =>  "−05",  # Cuba Standard Time
CT  =>  "+08",  # China Time
CVT =>  "−01",  # Cape Verde Time
CWST  =>  "+08:45", # Central Western Standard Time (Australia) unofficial
CXT =>  "+07",  # Christmas Island Time
DAVT  =>  "+07",  # Davis Time
DDUT  =>  "+10",  # Dumont d'Urville Time
DFT =>  "+01",  # AIX-specific equivalent of Central European Time[NB 1]
EASST =>  "−05",  # Easter Island Summer Time
EAST  =>  "−06",  # Easter Island Standard Time
EAT =>  "+03",  # East Africa Time
ECT =>  "−04",  # Eastern Caribbean Time (does not recognise DST)
ECT =>  "−05",  # Ecuador Time
EDT =>  "−04",  # Eastern Daylight Time (North America)
EEST  =>  "+03",  # Eastern European Summer Time
EET =>  "+02",  # Eastern European Time
EGST  =>  "+00",  # Eastern Greenland Summer Time
EGT =>  "−01",  # Eastern Greenland Time
EIT =>  "+09",  # Eastern Indonesian Time
EST =>  "−05",  # Eastern Standard Time (North America)
FET =>  "+03",  # Further-eastern European Time
FJT =>  "+12",  # Fiji Time
FKST  =>  "−03",  # Falkland Islands Summer Time
FKT =>  "−04",  # Falkland Islands Time
FNT =>  "−02",  # Fernando de Noronha Time
GALT  =>  "−06",  # Galápagos Time
GAMT  =>  "−09",  # Gambier Islands Time
GET =>  "+04",  # Georgia Standard Time
GFT =>  "−03",  # French Guiana Time
GILT  =>  "+12",  # Gilbert Island Time
GIT =>  "−09",  # Gambier Island Time
GMT =>  "+00",  # Greenwich Mean Time
GST =>  "−02",  # South Georgia and the South Sandwich Islands Time
GST =>  "+04",  # Gulf Standard Time
GYT =>  "−04",  # Guyana Time
HDT =>  "−09",  # Hawaii–Aleutian Daylight Time
HAEC  =>  "+02",  # Heure Avancée d'Europe Centrale French-language name for CEST
HST =>  "−10",  # Hawaii–Aleutian Standard Time
HKT =>  "+08",  # Hong Kong Time
HMT =>  "+05",  # Heard and McDonald Islands Time
HOVST =>  "+08",  # Khovd Summer Time
HOVT  =>  "+07",  # Khovd Standard Time
ICT =>  "+07",  # Indochina Time
IDLW  =>  "−12",  # International Day Line West time zone
IDT =>  "+03",  # Israel Daylight Time
IOT =>  "+03",  # Indian Ocean Time
IRDT  =>  "+04:30", # Iran Daylight Time
IRKT  =>  "+08",  # Irkutsk Time
IRST  =>  "+03:30", # Iran Standard Time
IST =>  "+05:30", # Indian Standard Time
IST =>  "+01",  # Irish Standard Time[5]
IST =>  "+02",  # Israel Standard Time
JST =>  "+09",  # Japan Standard Time
KALT  =>  "+02",  # Kaliningrad Time
KGT =>  "+06",  # Kyrgyzstan Time
KOST  =>  "+11",  # Kosrae Time
KRAT  =>  "+07",  # Krasnoyarsk Time
KST =>  "+09",  # Korea Standard Time
LHST  =>  "+10:30", # Lord Howe Standard Time
LHST  =>  "+11",  # Lord Howe Summer Time
LINT  =>  "+14",  # Line Islands Time
MAGT  =>  "+12",  # Magadan Time
MART  =>  "−09:30", # Marquesas Islands Time
MAWT  =>  "+05",  # Mawson Station Time
MDT =>  "−06",  # Mountain Daylight Time (North America)
MET =>  "+01",  # Middle European Time Same zone as CET
MEST  =>  "+02",  # Middle European Summer Time Same zone as CEST
MHT =>  "+12",  # Marshall Islands Time
MIST  =>  "+11",  # Macquarie Island Station Time
MIT =>  "−09:30", # Marquesas Islands Time
MMT =>  "+06:30", # Myanmar Standard Time
MSK =>  "+03",  # Moscow Time
MST =>  "+08",  # Malaysia Standard Time
MST =>  "−07",  # Mountain Standard Time (North America)
MUT =>  "+04",  # Mauritius Time
MVT =>  "+05",  # Maldives Time
MYT =>  "+08",  # Malaysia Time
NCT =>  "+11",  # New Caledonia Time
NDT =>  "−02:30", # Newfoundland Daylight Time
NFT =>  "+11",  # Norfolk Island Time
NPT =>  "+05:45", # Nepal Time
NST =>  "−03:30", # Newfoundland Standard Time
NT  =>  "−03:30", # Newfoundland Time
NUT =>  "−11",  # Niue Time
NZDT  =>  "+13",  # New Zealand Daylight Time
NZST  =>  "+12",  # New Zealand Standard Time
OMST  =>  "+06",  # Omsk Time
ORAT  =>  "+05",  # Oral Time
PDT =>  "−07",  # Pacific Daylight Time (North America)
PET =>  "−05",  # Peru Time
PETT  =>  "+12",  # Kamchatka Time
PGT =>  "+10",  # Papua New Guinea Time
PHOT  =>  "+13",  # Phoenix Island Time
PHT =>  "+08",  # Philippine Time
PKT =>  "+05",  # Pakistan Standard Time
PMDT  =>  "−02",  # Saint Pierre and Miquelon Daylight Time
PMST  =>  "−03",  # Saint Pierre and Miquelon Standard Time
PONT  =>  "+11",  # Pohnpei Standard Time
PST =>  "−08",  # Pacific Standard Time (North America)
PST =>  "+08",  # Philippine Standard Time
PYST  =>  "−03",  # Paraguay Summer Time[6]
PYT =>  "−04",  # Paraguay Time[7]
RET =>  "+04",  # Réunion Time
ROTT  =>  "−03",  # Rothera Research Station Time
SAKT  =>  "+11",  # Sakhalin Island Time
SAMT  =>  "+04",  # Samara Time
SAST  =>  "+02",  # South African Standard Time
SBT =>  "+11",  # Solomon Islands Time
SCT =>  "+04",  # Seychelles Time
SDT =>  "−10",  # Samoa Daylight Time
SGT =>  "+08",  # Singapore Time
SLST  =>  "+05:30", # Sri Lanka Standard Time
SRET  =>  "+11",  # Srednekolymsk Time
SRT =>  "−03",  # Suriname Time
SST =>  "−11",  # Samoa Standard Time
SST =>  "+08",  # Singapore Standard Time
SYOT  =>  "+03",  # Showa Station Time
TAHT  =>  "−10",  # Tahiti Time
THA =>  "+07",  # Thailand Standard Time
TFT =>  "+05",  # Indian/Kerguelen
TJT =>  "+05",  # Tajikistan Time
TKT =>  "+13",  # Tokelau Time
TLT =>  "+09",  # Timor Leste Time
TMT =>  "+05",  # Turkmenistan Time
TRT =>  "+03",  # Turkey Time
TOT =>  "+13",  # Tonga Time
TVT =>  "+12",  # Tuvalu Time
ULAST =>  "+09",  # Ulaanbaatar Summer Time
ULAT  =>  "+08",  # Ulaanbaatar Standard Time
UTC  => "+00",  # Coordinated Universal Time
UYST  =>  "−02",  # Uruguay Summer Time
UYT =>  "−03",  # Uruguay Standard Time
UZT =>  "+05",  # Uzbekistan Time
VET =>  "−04",  # Venezuelan Standard Time
VLAT  =>  "+10",  # Vladivostok Time
VOLT  =>  "+04",  # Volgograd Time
VOST  =>  "+06",  # Vostok Station Time
VUT =>  "+11",  # Vanuatu Time
WAKT  =>  "+12",  # Wake Island Time
WAST  =>  "+02",  # West Africa Summer Time
WAT =>  "+01",  # West Africa Time
WEST  =>  "+01",  # Western European Summer Time
WET   =>  "+00",  # Western European Time
WIT =>  "+07",  # Western Indonesian Time
WST =>  "+08",  # Western Standard Time
YAKT  =>  "+09",  # Yakutsk Time
YEKT  =>  "+05"  # Yekaterinburg Time
  };
}

method daysPerMonth ( $year ) {
  my $monthdays = {
    1 => 31,
    2 => 28, # 29 IN LEAP YEAR
    3 => 31,
    4 => 30,
    5 => 31,
    6 => 30,
    7 => 31,
    8 => 31,
    9 => 30,
    10 => 31,
    11 => 30,
    12 => 31
  };

  # HANDLE LEAP YEAR
  if ( $year % 4 == 0 ) {
    $monthdays->{2} = 29;
  }

  return $monthdays;
}


1;
