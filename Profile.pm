use MooseX::Declare;

use strict;
use warnings;

=head

  METHOD: doProfileInheritance 

  PURPOSE: ADD FIELDS FROM ONE OR MORE INHERITED PROFILES.

  THE ORDER OF PRIORITY IS "FIRST TO LAST",  I.E., IF THE 

  inherits FIELD IS AS FOLLOWS:


   testprofile:

     inherits : first,second,third


  ... THEN:
     
    1. THE PROFILES first, second AND third MUST ALSO BE PRESENT

    IN THE profiles.yml FILE (EXITS IF THIS IS NOT THE CASE)

    2. THE FIELDS FROM PROFILE first WILL BE ADDED TO THE FIELDS

    IN PROFILE testprofile WITHOUT OVERWRITING EXISTING FIELDS IN

    testprofile

    3. THE FIELDS IN PROFILE second WILL SIMILARLY BE ADDED TO

    PROFILE testprofile WITHOUT OVERWRITING ANY EXISTING FIELDS

    4. LASTLY, THE FIELDS IN PROFILE third WOULD BE ADDED WITHOUT

    OVERWRITING ANY FIELDS ORIGINALLY IN PROFILE testprofile OR

    ADDED TO IT FROM PROFILES first AND second
=cut

class Util::Profile with Util::Logger {

use Data::Dumper;


# Integers
has 'log'             =>  ( isa => 'Int', is => 'rw', default => 2 );   
has 'printlog'        =>  ( isa => 'Int', is => 'rw', default => 2 );

# Strings
has 'profilename'     => ( isa => 'Str|Undef', is => 'rw' );

# Objects
has 'profiles'        => ( isa => 'HashRef', is => 'rw' );
has 'profilehash'     => ( isa => 'HashRef', is => 'rw' );

method BUILD ( $args ) {

  if ( defined $args->{ profiles } ) {
    my $profiles = $self->yamlFileToData( $args->{ profiles } );
    $self->logDebug( "profiles", $profiles );
    $self->profiles( $profiles ); 
    if ( defined $args->{ profilename } ) {
      my $profilehash = $
    }

  }
  elsif ( defined $args->{ yaml } ) {
    my $profilehash = $self->yamlToData( $args->{ yaml } );
    $self->profilehash( $profilehash ); 
  }
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


method doProfileInheritance ( $profilename ) {
  $self->logDebug( "profilename", $profilename );
  my $profiles = $self->profiles();
  $self->logDebug( "profiles", $profiles );
  
  my $profilehash = $profiles->{$profilename};
  my $inherits = $profilehash->{inherits};
  $self->logDebug( "inherits", $inherits );
  if ( not $inherits ) {
    return $profilehash;
  }

  my @inheritedprofiles = split ",", $inherits;
  foreach my $inheritedprofile ( @inheritedprofiles ) {
    my $inherited = $profilehash->{$inheritedprofile};
    if ( not $inherited ) {
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

method yamlToData ( $text ) {
  # $self->logDebug( "text", $text );
  return {} if not $text;

  my $yaml = YAML::Tiny->new();
  my $yamlinstance = $yaml->read_string( $text );
  my $data = $yamlinstance->[0];
  # $self->logDebug( "data", $data );

  return $data;
}

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

method yamlFileToData ( $file ) {
  $self->logDebug( "file", $file );

  return undef if not $file;

  my $yaml = YAML::Tiny->read( $file );
  
  return $$yaml[0];
}


} #### class