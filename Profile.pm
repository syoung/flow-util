use MooseX::Declare;

use strict;
use warnings;

class Util::Profile with Util::Logger {

use Data::Dumper;
use Sys::Hostname;

# Integers
has 'log'             =>  ( isa => 'Int', is => 'rw', default => 2 );   
has 'printlog'        =>  ( isa => 'Int', is => 'rw', default => 2 );

# Strings
has 'profilefile'     => ( isa => 'Str|Undef', is => 'rw' );
has 'profilename'     => ( isa => 'Str|Undef', is => 'rw' );
has 'profilestring'   => ( isa => 'Str|Undef', is => 'rw' );

# Objects
has 'profiles'        => ( isa => 'HashRef|Undef', is => 'rw' );
has 'profilehash'     => ( isa => 'HashRef|Undef', is => 'rw' );

=head
  Instantiate class and process optional arguments:

      profiles      String - YAML contents of profile file. 
      profilefile   String - Location of YAML profile file

      profilename  String - Name of profile

    Generate 'profiles' hash attribute given 'profiles' or 'profilefile' arguments, with the contraint that 'profiles' takes priority over 'profilefile'.

    Generate 'profilehash' hash attribute from 'profilename' argument.

=cut
method BUILD ( $args ) {

  # print "Util::Profile::BUILD    args:\n";
  # print Dumper $args;

  #### SET LOGS
  $self->log( $args->{ log } ) if defined $args->{ log };
  $self->printlog( $args->{ printlog } ) if defined $args->{ printlog };
  # $self->logDebug( "args", $args );

  my $profilefile = $args->{ profilefile }; 
  if ( defined $profilefile ) {
    #### CONVERT YAML IN FILE TO profiles HASH 
    my $profiles = $self->yamlFileToData( $profilefile );
    $self->logDebug( "profiles", $profiles );
    $self->profiles( $profiles );
  }

  my $profilestring = $args->{ profilestring }; 
  if ( defined $profilestring ) {
    #### CONVERT YAML IN FILE TO profiles HASH 
    my $profiles = $self->yamlToData( $profilestring );
    $self->logDebug( "profiles", $profiles );
    $self->profiles( $profiles );
  }

  my $profilename = $args->{ profilename };
  $self->profilename( $profilename );
  $self->logDebug( "profilename", $profilename );

  if ( defined $profilename ) {
    my $profilehash = $self->profiles()->{ $profilename };
    $self->logDebug( "profilehash", $profilehash );
    $self->profilehash( $profilehash );
 }
}

=head

  Insert profile values in String where '<profile:...key...>' is found, provided that:

  - 'key' is ':'-separated string denoting the node path, e.g.:

  a:b:c denotes:

    a:
      b:
        c

  - Node path denoted by 'key' exists in the profilehash

  - Return undef if any 'key' doesn't exist in the profilehash

=cut
method insertProfileValues ( $data ) {
  $self->logDebug( "data", $data );

  my $profilehash = $self->profilehash();
  $self->logDebug( "profilehash", $profilehash );

  foreach my $key ( keys %$data ) {
    # $self->logDebug( "DOING key $key" );
    my $string = $data->{ $key };

    next if not $string;
    $data->{ $key } = $self->replaceString( $string );
    if ( not defined $data->{ $key } ) {
      $self->logError( "**** PROFILE PARSING FAILED. RETURNING undef TO TRIGGER ROLLBACK ****");
      return undef;
    }
  }
  # $self->logDebug( "data", $data );

  return $data;
}

method replaceString( $string ) {
  $self->logDebug( "string", $string );

  my $profilehash = $self->profilehash();
  # $self->logDebug( "profilehash", $profilehash );
  return $string if not defined $profilehash;

  while ( $string =~ /<profile:([^>]+)>/ ) {
    my $keystring = $1;
    $self->logDebug( "string", $string );
    my $value = $self->getProfileValue( $keystring, $profilehash );
    # $self->logDebug( "value", $value );

    if ( not $value ) {
      $self->logError( "*** ERROR *** Can't find profile value for key: $keystring ****" );
      return undef;
    }

    #### ONLY INSERT SCALAR VALUES
    if ( ref( $value ) ne "" ) {
      # print "Profile value is not a string: " . YAML::Tiny::Dump( $value ) . "\n";
      $self->logError( "Profile value is not a string: " . YAML::Tiny::Dump( $value ) . "\n" );
      return undef;
    }

    $string =~ s/<profile:$keystring>/$value/ if defined $value;
  }

  return $string;
}

method getProfileValue ( $keystring ) {
  $self->logDebug( "keystring", $keystring );
  my @keys = split ":", $keystring;
  my $hash = $self->profilehash();
  foreach my $key ( @keys ) {
    $hash  = $hash->{$key};
    return undef if not defined $hash;
    # $self->logDebug("hash", $hash);
  }

  return $hash;
}

# method setProfileValue ( $keystring, $profile, $value ) {
#   $self->logDebug( "keystring", $keystring );
#   my @keys = split ":", $keystring;
#   my $hash = $profile;
#   foreach my $key ( @keys ) {
#     $hash  = $hash->{$key};
#     return undef if not defined $hash;
#     $self->logDebug("hash", $hash);
#   }

#   return $hash;
# }

=head

  Use profilename to set 'profilehash' attribute, assuming 'profiles' attribute is defined.

  ADD FIELDS FROM ONE OR MORE INHERITED PROFILES, BASED ON A "FIRST TO LAST" ORDER OF DECREASING PRIORITY. 

  FOR EXAMPLE, IF THE  inherits FIELD IS AS FOLLOWS:

     inherits : first,second,third

  THEN:
     
    1. THE PROFILES first, second AND third MUST ALSO BE PRESENT IN profiles.yml (EXIT PROGRAM IF NOT PRESENT)

    2. ADD FIELDS FROM PROFILE 'first' TO profilehash WITHOUT OVERWRITING EXISTING FIELDS

    3. SIMILARLY, ADD FIELDS IN PROFILE 'second' TO profilehash WITHOUT OVERWRITING ANY EXISTING FIELDS

    4. LASTLY, ADD FIELDS IN PROFILE 'third' TO profilehash WITHOUT OVERWRITING ANY EXISTING FIELDS (POTENTIALLY ADDED FROM PROFILES 'first' AND 'second')

  Arguments:

  profilename    -- String: name of profile

=cut

method getHostType {
  
  my $runtype = $self->getProfileValue( "run:type" ) || "Shell";
  my $hostname = $self->getProfileValue( "host:name" ) || "Local";

  my $hosttype = "Local";
  if ( defined $self->getProfileValue( "virtual" ) ) {
    $self->logDebug( "SETTING hosttype TO Remote" );
    $hosttype = "Remote"; 
  }
  # else {
  #   my $thishost = Sys::Hostname::hostname || "";
  #   $self->logDebug( "thishost", $thishost );
  #   if ( $hostname ne "localhost" ) {
  #     if ( $thishost and $hostname ) {
  #       if ( $hostname ne $thishost ) {
  #           $hosttype = "Remote";
  #       }
  #     }
  #     else {
  #       $hosttype = "Remote";
  #     }
  #   }
  # }

  $hosttype = $self->cowCase( $hosttype );
  $runtype = $self->cowCase( $runtype );
  $self->logDebug( "runtype", $runtype );
  $self->logDebug( "hosttype", $hosttype );

  return ( $hosttype, $runtype );
}

method cowCase ( $string ) {
  return undef if not $string;

  return uc( substr( $string, 0, 1) ) . substr( $string, 1);
}

method setProfileHash ( $profilename ) {
  $self->logDebug( "profilename", $profilename );
  $self->profilename( $profilename );
  my $profiles = $self->profiles();
  $self->logDebug( "profiles", $profiles );
  if ( not $profiles or not $profilename ) {
    $self->logWarning( "profiles NOT DEFINED", $profiles );
    $self->profilehash( undef );
    return undef;
  }

  my $profilehash = $profiles->{ $profilename };
  $self->logDebug( "profilehash", $profilehash );
  $self->profilehash( $profilehash );

  if ( not defined $profilehash ) {
    $self->logWarning( "profilehash NOT DEFINED", $profilehash );
    return undef;
  }

  my $inherits = $profilehash->{inherits};
  $self->logDebug( "inherits", $inherits );
  if ( not $inherits ) {
    return $profilehash;
  }

  my @inheritedprofiles = split ",", $inherits;
  foreach my $inheritedprofile ( @inheritedprofiles ) {
    my $inherited = $profiles->{ $inheritedprofile };
    if ( not $inherited ) {
      $self->logCritical( "Inherited profile not found in profiles.yml file: $inheritedprofile\n" );
      print "Inherited profile '$inheritedprofile' not found in profiles.yml file\n";
      exit;
    }

    foreach my $key ( keys %$inherited ) {
      $self->logDebug( "key", $key );
      $profilehash->{ $key } = $self->recurseInheritance ( $profilehash->{$key}, $inherited->{$key} ); 
    }
  }

  $self->logDebug( "RETURNING profile", $profilehash, 1 );
  $self->profilehash( $profilehash );

  return $profilehash;
}

method recurseInheritance ( $profilefield, $inheritedfield ) {
  $self->logDebug( "profilefield", $profilefield );
  $self->logDebug( "inheritedfield", $inheritedfield );

  #### INHERITED FIELD DOES NOT EXIST IN profile SO ADD IT 
  if ( not defined $profilefield ) {
    return $inheritedfield;
  }

  my $profiletype = ref( $profilefield );
  my $inheritedtype = ref( $inheritedfield );
  $self->logDebug( "profiletype", $profiletype );
  $self->logDebug( "inheritedtype", $inheritedtype );

  if ( $profiletype ne $inheritedtype ) {
    print "Mismatch between profile data types.\n";
    print "Original key type: $profiletype\n";
    print "Inherited key type: $inheritedtype\n";
    exit;
  }

  #### IF BOTH ARE ARRAYS, ADD TO PROFILE MISSING ENTRIES 
  if ( $profiletype eq "HASH" ) {

    foreach my $key ( keys %$inheritedfield ) {
      $profilefield->{ $key } = $self->recurseInheritance ( $profilefield->{ $key 
      }, $inheritedfield->{ $key } ); 
    }
  }
  elsif ( $profiletype eq "ARRAY" ) {
    foreach my $entry ( @$inheritedfield ) {
      if ( not $self->elementInArray( $profilefield, $entry ) ) {
        $self->logDebug( "ADDING entry", $entry );
        push @$profilefield, $entry;
      }
    }
  }

  #### OTHERWISE, KEEP THE EXISTING VALUE IN profile
  return $profilefield;
}

method elementInArray ( $array, $entry ) {
  $self->logDebug( "array", $array );
  $self->logDebug( "entry", $entry );

  my $x = Dumper( $entry );
  foreach my $slot ( @$array ) {
    my $y = Dumper( $slot );
    if( $x eq $y ) {
      return 1;
    }
  }

  return 0;
}

=head
  Return YAML text string of 'profilehash' attribute.
=cut
method getProfileYaml() {
  my $profilehash = $self->profilehash();
  $self->logDebug( "profilehash", $profilehash );

  return $self->dataToYaml( $profilehash );
}

=head
  Convert YAML text string to data object.
=cut
method yamlToData ( $text ) {
  # $self->logDebug( "text", $text );
  return {} if not $text;

  my $yaml = YAML::Tiny->new();
  my $yamlinstance = $yaml->read_string( $text );
  my $data = $yamlinstance->[0];
  # $self->logDebug( "data", $data );

  return $data;
}

=head
  Convert data object to YAML text string.
=cut
method dataToYaml ( $data ) {
  $self->logDebug( "data", $data );
  return "" if not $data;

  my $yaml = YAML::Tiny->new();
  $$yaml[ 0 ] = $data;
  my $text = $yaml->write_string( $data );
  $text =~ s/\'/\"/g;
  $self->logDebug( "text", $text );

  return $text;
}

=head
  Return data object converted from YAML contents of file.
=cut
method yamlFileToData ( $file ) {
  $self->logDebug( "file", $file );

  return undef if not $file;

  my $yaml = YAML::Tiny->read( $file );
  
  return $self->yamlToData( $yaml );
}

=head
  Return data object converted from YAML contents of file.
=cut
method getFileYaml ( $file ) {
  $self->logDebug( "file", $file );

  return undef if not $file;

  my $yaml = YAML::Tiny->read( $file );
  
  return $yaml;
}

} #### class