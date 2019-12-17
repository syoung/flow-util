package Util::Script;
use Moose::Role;
use Method::Signatures::Simple;

#### EXTERNAL MODULES
use Getopt::Std;
use Term::ANSIColor qw(:constants);
use Data::Dumper;

#### SET PIPELINE GENERATION
our $PIPELINE_GENERATION = 4;

#### SET UMASK
umask 0000;


=head2

	SUBROUTINE		checkdefined
	
	PURPOSE
	
		CHECK IF A VARIABLE IS DEFINED, RETURN 1 IF DEFINED,
		EXIT WITH ERROR MESSAGE IF NOT DEFINED

=cut

method check_defined ( $variable, $message ) {
	if ( not defined $variable ) {
		print "$message\n";
		return;
	}
	
	return 1;
}


=head2

	SUBROUTINE		checkdir
	
	PURPOSE
	
		CHECK IF A dir EXISTS. IF NOT, PRINT A MESSAGE AND CALL A SUBROUTINE

=cut

method checkdir ( $dir, $message, $subroutine ) {
	if ( not -d $dir ) {
		print "$message\n" if defined $message;
		&$subroutine() if defined $subroutine;
		return 0;
	}
	
	return 1;
}



=head2

	SUBROUTINE		checkfile
	
	PURPOSE
	
		CHECK IF A FILE EXISTS. IF NOT, PRINT A MESSAGE AND CALL A SUBROUTINE

=cut

method checkfile ( $file, $message, $subroutine ) {
	if ( not -f $file ) {
		print "$message\n" if defined $message;
		&$subroutine() if defined $subroutine;
	}
	else {
		
	}
}



=head2

    SUBROUTINE      round
    
    PURPOSE
    
        ROUND TO THE NEAREST INTEGER
        
=cut

method round ( $number ) {    
    my $int= int($number);
    if ( $number > $int + 0.5 ) {   return $int + 1;    }
    
    return $int;
}
    

=head2

    SUBROUTINE      by_key
    
    PURPOSE
    
        SORT AN ARRAY OF HASHES OUT BY KEY
        
=cut

method by_key {
    my ($a, $b) = @_;
    my $aa = $$a[0];
    my $bb = $$b[0];
    
    $aa <=> $bb;
}




=head2

	SUBROUTINE		copy_hasharray
    
	PURPOSE

		COPY AN ARRAY OF HASHES
		
=cut


method copy_hasharray ( $array ) {
    if ( not defined $array )   {   return; }    
    my $newarray;
    for ( my $i = 0; $i < @$array; $i++ ) {
        my $newhash = Util::copy_hash($$array[$i]);
        push @$newarray, $newhash;
    }
    
    return $newarray;
}


=head2

	SUBROUTINE		convert_hash
	
	PURPOSE

		USE A HASH FIELD MAPPING TO CONVERT FROM ONE HASH TO ANOTHER
		
=cut

method convert_hash ( $hash, $mapping ) {
	my $new_hash;
	foreach my $key ( keys %$hash ) {
		if ( not exists $mapping->{$key} )	{	next;	}	
		$new_hash->{ $mapping->{$key} } = $hash->{$key};
	}
	
	return $new_hash;	
}



=head2

	SUBROUTINE		create_directory

	PURPOSE

		CREATE A DIRECTORY, IF NOT EXISTS
		
=cut

method create_directory ( $directory ) {
	if ( not -d $directory ) {
		
		`mkdir -p $directory`;
		
	}
}

=head2

	SUBROUTINE		conf

	PURPOSE

		READ THE ROOT DIRECTORY, MYSQL USER AND PASSWORD, AND
		
		OTHER CONFIGURATION DATA FROM THE myEST.conf FILE IN THE
		
		bin/pipeline<PIPELINE_GENERATION> DIRECTORY
		
=cut

method conf ( $directory, $is_file ) {
	my $configfile = $directory;	
	my $lines = Util::lines($configfile);
	if ( not defined $lines ) {	print "Could not open config file: '$configfile'. Error message: !@\n\n";	}
	
	my $conf;
	for ( my $i = 0; $i < @$lines; $i++ ) {
		my $line = $$lines[$i];
		print "line: $line\n";
		if ( $line =~ /^\s*$/ )	{	next;	}
		
		if ( $line =~ /\s*(\S+)\s+(\S+)\s*/ ) {
			my $parameter = $1;
			my $value = $2;
			print "value: $value\n";
			if ( defined $value and $value ) {
				$conf->{$parameter} = $value;
			}
		}
	}
	
	return $conf;
}



=head2

	SUBROUTINE		splitfile

	PURPOSE

		PRINT AN ARRAY OF RECORDS EVENLY INTO AS MANY FILES AS
		
		THE NUMBER GIVEN OR THE MAX NUMBER OF RECORDS (WHICHEVER
		
		IS LESS)

	NOTES
	
		DEFAULT RECORD TYPE IS FASTA
		
	REQUIRES
	
		Util::records
		
=cut

method splitfile ( $inputfile, $number_files, $outputfile_stem, $separator ) {
	# print "Inputfile: $inputfile\n";
	# print "Files: $number_files\n";
	# print "Output filestem: $outputfile_stem\n";
	# print "Separator: $separator\n";
	
	#### DEFAULT RECORD TYPE IS FASTA
	if ( not defined $separator ) {
		$separator = "\\n>";
	}

	#### PRINT FILENAMES IF DEBUG	
	print "Inputfile: $inputfile\n";
	print "files: $number_files\n";
	print "Outputfile stem: $outputfile_stem\n";	
	
	my $number_records = Util::records($inputfile, $separator);
	print "No. records: $number_records\n";	
	print "Tasks: $number_files\n";

	#### SET NUMBER OF FILES DEPENDING ON NUMBER OF SEQUENCES
	if ( $number_files > $number_records )	{	$number_files = $number_records;	}
	print "Tasks (after sequence number adjustment): $number_files\n";

	#### PRINT EVENLY DIVIDED SEQUENCES IN ALL QUERY OUTPUT FILES
	my $records_per_file = 0;
	if ( $number_records > $number_files ) {
		$records_per_file = floor( $number_records / $number_files);
	}
	print "Records per file: $records_per_file\n";

	#### ADD ONE EXTRA SEQUENCE TO remainder NUMBER OF QUERY OUTPUT FILES
	my $remainder = 0;
	if ( $number_records > $number_files ) {
		$remainder = $number_records % $number_files;
	}
	print "Remainder: $remainder\n";

	#### GET THE NUMBER OF FASTA RECORDS TO BE PRINTED TO EACH FILE
	print "Doing first pass...\n";
	my $file_records;
	for ( my $file_counter = 1; $file_counter < $number_files + 1; $file_counter++ ) {
		$$file_records[$file_counter] = $records_per_file;	
	}
	print "First pass finished\n";
	print "Sequences: @$file_records\n";
	print "Doing remainder...\n";
	for ( my $file_counter = 1; $file_counter < $remainder + 1; $file_counter++ ) {
		
		$$file_records[$file_counter]++;
	}
	print "Remainder finished\n";
	print "File records: @$file_records\n";

	#### OPEN INPUT FILE
	$/ = $separator;
	open(FILE, $inputfile) or die "Can't open input fasta file: $inputfile\n";
	
	#### PRINT FASTA RECORDS TO QUERY FILES	
	my $total_record_counter = 0;
	for ( my $file_counter = 1; $file_counter < $number_files + 1; $file_counter++ ) {
		#### SET AND OPEN OUTPUT QUERY FILE
		my $queryfile = $outputfile_stem . ".$file_counter";
		print "Printing queryfile '$queryfile'\n";
		open(OUTFILE, ">$queryfile");
		
		#### GET NUMBER OF FASTA RECORDS
		my $records = $$file_records[$file_counter];
		
		
		#### PRINT FASTA RECORDS TO QUERY FILE		
		for ( my $record_counter = 0; $record_counter < $records; $record_counter++ ) {
			$total_record_counter++;
			
			#### PRINT FIRST '>' OR OTHER SEPARATOR
			if ( $record_counter == 0 ) {
				print OUTFILE $separator;
			}

			my $record = <FILE>;
			print OUTFILE $record;
			#print "Record $total_record_counter printed to file $queryfile [no. sequences: $number_records]\n";
		}	
		close(OUTFILE);
	}
	print "Done printing query files\n";

	return $number_files;
}


=head2

	SUBROUTINE		floor
	
	PURPOSE
	
		RETURN THE FLOOR OF ANY POSITIVE NUMBER

=cut

method floor ( $number ) {
	my $floor = int($number);

	if ( $floor > $number )	{	return $floor - 1;	}	
	else 	{	return $floor;	}
}




=head2

	SUBROUTINE		records
	
	PURPOSE
	
		COUNT THE NUMBER OF RECORDS IN A FILE GIVEN THE RECORD SEPARATOR
		
		(DEFAULT = FASTA)

=cut

method records ( $self, $filename, $separator ) {
	# print "Filename: $filename\n";
	# print "Separator: $separator\n";
	
	if ( not defined $filename ) {	return;	}
	if ( not -f $filename ) { print "Can't find file: $filename \n\n"; return; }
	
	#### SET RECORD SEPARATOR '$/'	
	if ( not defined $separator ) {
		$/ = "\n>";
	}
	else {
		$/ = $separator;
	}

	my $counter = 0;
	open(FILE, $filename) or die "Util::records Can't open file '$filename'\n";
	while ( my $record = <FILE> )    {    $counter++;    } 
	close(FILE);

	return $counter;
}


=head2

	SUBROUTINE		transmute_hash
	
	PURPOSE
	
		CHANGE THE KEY NAMES OF A HASH

=cut

method transmute_hash ( $hash, $keys ) {
	foreach my $key (keys %$keys ) {
		
		my $value = $keys->{$key};
		
		$hash->{$value} = $hash->{$key};
		$hash->{$key} = undef;
	}
	
	return $hash;
}


=head2

	SUBROUTINE		create_parentdir
	
	PURPOSE
	
		CREATE THE PARENT DIRECTORY OF A FILE GIVEN ITS FULL PATH

=cut

method create_parentdir ( $filepath ) {
	my $parentdir = parentdir($filepath);
	if ( defined $parentdir) {
		`mkdir -p $parentdir`;
	}
	
	return $parentdir;
}

=head2

	SUBROUTINE		parentdir
	
	PURPOSE
	
		RETURN THE PARENT DIRECTORY OF A FILE GIVEN ITS FULL PATH

=cut

method parentdir ( $filepath ) {
	my ($parentdir) = $filepath =~ /^(.+)\/[^\/]+$/;
	if ( not defined $parentdir) {
		print "File path has no parent directory: $filepath\n\n";
		return;
	}
	
	return $parentdir;
}

=head2

	SUBROUTINE		input_range
	
	PURPOSE
	
		FIND THE RANGE OF VALUES IN A GIVEN INPUT
		
		AND RETURN THEM IN AN ARRAY REFERENCE.
		
		THE VALUES CAN BE ANY COMBINATION OF:
		
			- HYPHEN-SEPARATED (ALL SINGLE INCREMENTS BETWEEN
			
				THE MIN AND MAX WILL BE RETURNED)
		
			- COMMA-SEPARATED (ALL DISTINCT VALUES WILL BE
			
				RETURNED)
			
			- SINGLE (ONE VALUE RETURNED IN ARRAY REF)
	
		E.G.: "1-5,10,15,20" WILL RETURN 1,2,3,4,5,10,15,20		
	
=cut

method input_range ( $input_string ) {
	$input_string =~ s/^\s//g;
	my $input_range;
	
	while ( length($input_string) > 0 ) {
		
		if ( $input_string =~ /^([^\-]+)\-([^\-]+)/ ) {
			for ( my $i = $1; $i < $2 + 1; $i++ ) {
				push @$input_range, $i;
			}
			$input_string 	=~ s/^[^\-]+\-[^\-]+//;
		}
		elsif ( $input_string =~ /^([^\-^,]+),*/ ) {
			push @$input_range, $1;
			$input_string 	=~ s/^[^\-^,]+,*//;
			#$input_string =~ s/^,//g;
		}
	}
	
	
	
	return $input_range;	
}

=head2

	SUBROUTINE		backup_file
	
	PURPOSE
	
		FIND THE NEXT ENTRY IN THE FILENAME SERIES
		*.bkp.1
		*.bkp.2
		...
		*bkp.N
		
		AND RETURN IT (E.G., *.bkp.N+1 )
	
=cut

method backup_file ( $filename ) {
	
	my $backup_file;
	my @files = `ls $filename.bkp.* 2> /dev/null`;
	@files = sort by_last_number @files;
	if ( not @files ) {
		$backup_file = "$filename.bkp.1";		
	}
	else {
		
		my $last_file = $files[$#files];
		my ($last_number) = $last_file =~ /(\d+)$/;
		$last_number++;
		$backup_file = "$filename.bkp.$last_number";
	}
	
	return $backup_file;
}



=head2

	SUBROUTINE		regex_safe
	
	PURPOSE
	
		CONVERT THE INPUT STRING INTO A FORM THAT CAN BE USED AS A REGEX
		
=cut


method regex_safe ( $string ) {
	$string =~ s/\./\\./g;
	$string =~ s/\-/\\-/g;
	$string =~ s/\[/\\[/g;
	$string =~ s/\]/\\]/g;
	$string =~ s/\(/\\(/g;
	$string =~ s/\)/\\)/g;
	$string =~ s/\*/\\*/g;
	$string =~ s/\+/\\+/g;
	
	return $string;
}


############################################################################
############################################################################
###################				HASH METHODS
############################################################################
############################################################################

=head2

	SUBROUTINE		sort_hasharray_by_key
	
	PURPOSE
	
		SORT A HASHARRAY BASED ON A SPECIFIED KEY
		
		SORT IS NON-CASE SPECIFIC
		
=cut

method sort_hasharray_by_key ( $hasharray, $key ) {
	$hasharray = [
		{ number => '4', rest=> '' },
		{ number=> 2, rest=> ''},
		{ number=> 3, rest=> ''},
		{ number=> 1, rest=> ''},
	];
	$key = "number";	
	@$hasharray = sort { $a->{key} cmp $b->{key} } @$hasharray;
	
	return $hasharray;
}


=head2

	SUBROUTINE		copy_hash
	
	PURPOSE
	
		COPY THE CONTENTS OF A HASH INTO A NEW HASH
		
		(WITHOUT USING A REFERENCE)
		
=cut

method copy_hash ( $hash ) {
	if ( not defined $hash )	{	return;	}
	
	my $new_hash;
	foreach my $key ( keys %$hash ) {
		$new_hash->{$key} = $hash->{$key};
	}
	
	return $new_hash;
}


=head2

	SUBROUTINE		number_matches
	
	PURPOSE
	
		COUNT THE NUMBER OF MATCHES FOR A GIVEN REGEX
		
=cut

method number_matches ( $string, $regex ) {
	use re 'eval';# EVALUATE $pattern AS REGULAR EXPRESSION
	my ($count) = $string =~ s/$regex//g;
	no re 'eval';# STOP EVALUATING AS REGULAR EXPRESSION

	return $count;
}


=head2

	SUBROUTINE		max
	
	PURPOSE
	
		DEPENDING ON THE INPUT:
		
		1. RETURN THE MAXIMUM VALUE BETWEEN THE TWO INPUT VALUES
		
			OR
		
		2. RETURN THE MAXIMUM VALUE OF AN ARRAY	
		
=cut

method max {
	if ( not ref($$_[0]) ) {
		if ( $_[0] < $_[1] ) {	return $_[1]	} else {	return $_[0]	};
	}
	elsif (	ref($_[0]) eq "ARRAY"  ) {		
		my $max = 0;
		for ( my $i = 0; $i < @$_[0]; $i++ ) {
			if ( $$_[0][$i] > $max )   {   $max = $$_[0][$i]; }
		}
	
	    return $max;
	}
}        

=head2

	SUBROUTINE		min
		
	PURPOSE
	
		DEPENDING ON THE INPUT:
		
		1. RETURN THE MINIMUM VALUE BETWEEN THE TWO INPUT VALUES
		
			OR
		
		2. RETURN THE MINIMUM VALUE OF AN ARRAY	
		
=cut

method min {
	if ( not ref($_[0]) ) {
		if ( $_[0] > $_[1] ) {	return $_[1]	} else {	return $_[0]	};
	}
	elsif (	ref($_[0]) eq "ARRAY"  ) {		
		my $min = 0;
		for ( my $i = 0; $i < @$_[0]; $i++ ) {
			if ( $$_[0][$i] < $min )   {   $min = $$_[0][$i]; }
		}
	
	    return $min;
	}
}        



=head2

	SUBROUTINE		bin_directory
	
	PURPOSE
	
		1. DETERMINE THE FULL PATH TO THE BINARY FILES DIRECTORY
		
=cut

method bin_directory {
	my $root_directory = root_directory();
	my $pipeline_generation = $PIPELINE_GENERATION;
	my $bindir = "$root_directory/bin/pipeline$pipeline_generation";
	
	return $bindir;
}



=head2

	SUBROUTINE
        
        root_directory
	
	PURPOSE:
	
		1. DETERMINE THE ROOT DIRECTORY BASED ON HOST NAME
        
        2. SET THE 'use' LIBRARY
		
=cut

method root_directory {
    my $root_directory;
    my $hostname = `hostname`;
    if ( $hostname =~ /^dlc-genomics.rsmas.miami.edu/ ) {
        $root_directory = "/Users/young/FUNNYBASE";
        #use lib "/Users/young/FUNNYBASE/lib";
    }
    else {
        $root_directory = "/Users/local/FUNNYBASE";
        #use lib "/Users/local/FUNNYBASE/lib";	
    }
    
    return $root_directory;
}



=head2

	SUBROUTINE:		add_hashes
	
	PURPOSE:
	
		THIS SUBROUTINE WILL ADD TWO HASHES.
		
	WARNING:
		
		ANY KEYS IN THE FIRST HASH THAT ARE IDENTICAL TO KEYS	
		IN THE SECOND HASH WILL HAVE THEIR VALUES OVERWRITTEN.
		
=cut


method add_hashes ( $hash1, $hash2 ) {
    my $newhash;
	if ( not defined $hash1 and not defined $hash2 )	{	return;	}	
    if ( not defined $hash1 ) {
        foreach (keys %$hash2)	{	$$newhash{$_} = $$hash2{$_};	}
        return $newhash;
    }
    if ( not defined $hash2 ) {
        foreach (keys %$hash1)	{	$$newhash{$_} = $$hash1{$_};	}
        return $newhash;
    }

    foreach (keys %$hash1)	{	$$newhash{$_} = $$hash1{$_};	}
    foreach (keys %$hash2)	{	$$newhash{$_} = $$hash2{$_};	}

    return $newhash;
}

method fasta_sequence ( $filename ) {
	my $fasta = contents($filename);
	my ($trash, $sequence) = split_fasta($fasta);

    return $sequence;
}


method fasta_header ( $filename ) {
	my $fasta = contents($filename);
	my ($header, $trash) = split_fasta($fasta);

    return $header;
}


method remove_files ( $files ) {
	my @remove		=	@_;

	for ( my $file_counter = 0; $file_counter < @$files; $file_counter++ ) {
		for ( my $remove_counter = 0; $remove_counter < $#remove + 1; $remove_counter++ ) {
			if ( $$files[$file_counter] =~ /^$remove[$remove_counter]$/ ) {
				splice @$files, $file_counter, 1;
				$file_counter--;
			}
		}
	}
	
	return $files;
}


method decimal_places ( $number, $decimal_places ) {
	my $sprintf = $decimal_places . "f";	
	$number = sprintf "%.$sprintf", $number;

	return $number;
}


method yes ( $message ) {
	if ( not defined $message )	{	$message = "Please input Y to continue, N to quit";	}

	$/ = "\n";
	my $input = <STDIN>;
	my $max = 10;
	my $counter = 0;
	while ( $input !~ /^Y$/i and $input !~ /^N$/i ) {
		if ( $counter > $max )	{	print "Exceeded 10 tries. Exiting...\n";	}
		
		print "$message\n";
		$input = <STDIN>;
		
		$counter++;
	}	
	if ( $input =~ /^N$/i )	{	return 0;	}
	else {	return 1;	}
}


method yesno {
	$| = 1;
	
	my $message = "Please input Y to continue, N to quit";

	$/ = "\n";
	my $input = <STDIN>;
	while ( $input !~ /^Y$/i and $input !~ /^N$/i ) {
		print "$message\n";
		$input = <STDIN>;
	}	
	if ( $input =~ /^N$/i )	{	exit;	}
	else {	return;	}
}


method yes_no ( $message ) {

	print "$message\n";
	$| = 1;

	$/ = "\n";
	my $input = <STDIN>;
	while ( $input !~ /^Y$/i and $input !~ /^N$/i ) {
		print "$message\n";
		$input = <STDIN>;
	}	
	if ( $input =~ /^N$/i )	{	return 0;	}
	else {	return 1;	}
}


method options ( $options_string ) {
	my %options = ();
	Getopt::Std::getopts( "$options_string", \%options );
	
	return %options;
}


method root_user {
	my $whoami = `whoami`;
	$whoami =~ s/\s+$//;
	if ( $whoami !~ /^local$/ ) {    return 1;   }

	return 0;
}

method array2hash ( $array ) {
	my $hash;
	for ( my $i = 0; $i < @$array; $i++ ) {
		if ( not exists $$hash{$$array[$i]} )	{	$$hash{$$array[$i]} = 1;	}
	}
	
	return $hash;
}

method choplines ( $filename ) {
	# SAVE LINE-END SETTING
	my $temp = $/;

	# SET LINE-END TO '\n'
	$/ = "\n";
	
	open(FILE, $filename) or die "Util::choplines    Can't open file '$filename'\n";
	my @lines = <FILE>;
	close(FILE);

    foreach my $line ( @lines ) {
        $line =~ s/\s+$//;
    }
	# RESTORE LINE-END TO ORIGINAL SETTING
	$/ = $temp;
	
	return wantarray ? @lines : \@lines;
}

method lines ( $filename ) {
	# SAVE LINE-END SETTING
	my $temp = $/;

	# SET LINE-END TO '\n'
	$/ = "\n";
	
	my $lines;
	open(FILE, $filename) or die "Util::lines    Can't open file '$filename'\n";
	while ( my $line = <FILE> ) {
		$line =~ s/\n$//;
		push @$lines, $line;
	}
	close(FILE);
	
	# RESTORE LINE-END TO ORIGINAL SETTING
	$/ = $temp;
	
	return wantarray ? @$lines : $lines;
}	


method contents ( $filename ) {
	if ( not -f $filename ) {
		print "Can't find file; $filename\n\n";
		return;
	}
	
	my $endline = $/;
	
	$/ = undef;
	open(FILE, $filename) or die "[Util::contents] Can't open file '$filename'\n";
	my $contents = <FILE>;
	close(FILE);
	$/ = $endline;

	return $contents;
}

	

method files ( $directory ) {
	$directory =~ s/\s//g;
	opendir(DIR, $directory);
	my @files = readdir(DIR);
	close(DIR);
    if ( not @files ) {
        return;
    }

	for ( my $i = 0; $i < $#files + 1; $i++ ) {
		if ( $files[$i] =~ /^\.$/ or $files[$i] =~ /^\.\.$/ ) {
			splice @files, $i, 1;
			$i--;
		}
	}
	
	return wantarray ? @files : \@files;
}

method by_suffix ( $files, $suffix ) {
	return files_by_suffix($files, $suffix);
	
}


method files_by_suffix ( $files, $suffix ) {
    if ( not defined $files ) {
        return;
    }

	my @suffixfiles = ();
	for ( my $i = 0; $i < @$files + 1; $i++ ) {
		if ( $$files[$i] ) {
			if ( $$files[$i] =~ /$suffix$/ ) {
				push @suffixfiles, $$files[$i];
			}
		}
	}

	return wantarray ? @suffixfiles : \@suffixfiles;
}

method by_prefix ( $files, $prefix ) {
	return files_by_prefix($files, $prefix);	
}


method files_by_prefix ( $files, $prefix ) {
	my @prefixfiles = ();
		
	for ( my $i = 0; $i < @$files + 1; $i++ ) {
		if ( $$files[$i] ) {
			if ( $$files[$i] =~ /^$prefix/ ) {
				push @prefixfiles, $$files[$i];
			}
		}
	}

	return wantarray ? @prefixfiles : \@prefixfiles;
}


method remove_suffix ( $files, $suffix ) {
	for ( my $i = 0; $i < @$files ; $i++ ) {
		$$files[$i] =~ s/$suffix$//;
	}

	return wantarray ? @$files : $files;	
}


method files_by_pattern ( $files, $pattern, $exclude ) {
	my $patternfiles = [];
		
	for ( my $i = 0; $i < @$files + 1; $i++ ) {
		if ( $$files[$i] ) {
			if ( $exclude ) {
				if ( $$files[$i] !~ /$pattern/ ) {
					push @$patternfiles, $$files[$i];
				}
			}
			else {
				if ( $$files[$i] =~ /$pattern/ ) {
					push @$patternfiles, $$files[$i];
				}
			}			
		}
	}

	return wantarray ? @$patternfiles: $patternfiles;	
}


method by_pattern ( $files, $pattern ) {
	my $patternfiles = ();
		
	for ( my $i = 0; $i < @$files + 1; $i++ ) {
		if ( $$files[$i] ) {
			if ( $$files[$i] =~ /$pattern/ ) {
				push @$patternfiles, $$files[$i];
			}
		}
	}
	
	return wantarray ? @$patternfiles : $patternfiles;	
}

=head

    SUBROUTINE      files_by_regex
    
    PURPOSE
    
        FILTER ARRAY BY REGEX AND RETURN FILTERED ARRAY
        
=cut


method files_by_regex ( $files, $pattern ) {
	return by_regex($files, $pattern);
}

=head

    SUBROUTINE      by_regex
    
    PURPOSE
    
        FILTER ARRAY BY REGEX AND RETURN FILTERED ARRAY
        
=cut

method by_regex ( $files, $pattern ) {
	my $patternfiles = ();
		
	for ( my $i = 0; $i < @$files + 1; $i++ ) {
		if ( $$files[$i] ) {
			use re 'eval';		# EVALUATE $pattern AS REGULAR EXPRESSION
			
			if ( $$files[$i] =~ /$pattern/ ) {
				push @$patternfiles, $$files[$i];
			}
			
			no re 'eval';		# STOP EVALUATING AS REGULAR EXPRESSION
		}
	}
	
	return wantarray ? @$patternfiles : $patternfiles;	
}


method NOT_pattern {
	my @files = files_by_NOT_pattern(@_);
	
	return wantarray ? @files : \@files;	
}


method files_by_NOT_pattern ( $files, $pattern ) {
	my @patternfiles = ();
		
	for ( my $i = 0; $i < @$files + 1; $i++ ) {
		if ( $$files[$i] ) {
			if ( $$files[$i] !~ /$pattern/ ) {
				push @patternfiles, $$files[$i];
			}
		}
	}

	return wantarray ? @patternfiles : \@patternfiles;	
}


method directories ( $directory ) {
	my $subdirectories = files($directory);
	
	for ( my $i = 0; $i < @$subdirectories; $i++ ) {
		if ( not -d "$directory/$$subdirectories[$i]" or $$subdirectories[$i] =~ /^[\.]{1,2}$/ ) {
			splice @$subdirectories, $i, 1;
			$i--;
		}
	}
	
	return wantarray ? @$subdirectories : $subdirectories;		
}


method files_in_subdirectories {
    my ($directory) = @_;

    opendir(DIR, $directory);
    my @subdirectories = readdir(DIR);
    close(DIR);

    my @files = ();
    for ( my $i = 0; $i < $#subdirectories + 1; $i++ ) {
        my @subfiles = files("$directory/$subdirectories[$i]");
        @files = ( @files, @subfiles);
    }

    return @files;
}



#######################################################################################################
#####					         create_viewfiles.pl SUBROUTINES  	    							#####
#######################################################################################################

method collect_fasta_contents ( $screenedfile_path, $filenames, $suffix ) {
	my $fasta_sequences = '';
		
	foreach my $file ( @$filenames ) {
		my $contents = contents("$screenedfile_path/$file$suffix");
		my ($header, $rest) = $contents =~ /^(.+?\n)(.+)$/ms;
		$fasta_sequences = $fasta_sequences . ">$file\n$rest";
	}
	
	return $fasta_sequences;
}


#######################################################################################################
#####					         		hmmer.pl SUBROUTINES  	    							#####
#######################################################################################################

method fasta_records ( $filename ) {
	my @fasta_records = ();
    
	my $separator = $/;
	$/ = undef;
	
	my $contents = contents($filename);
	open(FILE, $filename);
	@fasta_records = split( /\n>/, <FILE>);
	if ( not @fasta_records ) 	{	return;	}
	
	$fasta_records[0] =~ s/^>//;
	
	$/ = $separator;
	
	return wantarray ? @fasta_records : \@fasta_records;
}

method split_fasta ( $sequence_record ) {
	if ( not defined $sequence_record ) { return; }
    my ($header) = $sequence_record =~ /^>?([^\n]+)\n*/;
	my ($sequence) = $sequence_record =~ /^>?[^\n]+\n(.+)$/ms;

	
	
    return ($header, $sequence);
}


method trim_whitespace ( $string ) {
	if ( $string ) {
		$string =~ s/\n//g;
		$string =~ s/\s//g;
		return $string;
	}
	else {
		return '';
	}
}


method print_file ( $outputfile, $content, $dielabel ) {
	if ( not $dielabel ) { 
		$dielabel = "output";
	}

	open(OUTPUTFILE, ">$outputfile") or die "[Util::print_file] Can't open $dielabel file '$outputfile'\n";

	if ( ref($content) =~ /^ARRAY$/ ) {
		for ( my $i = 0; $i < @$content; $i++ ) {
			print OUTPUTFILE $$content[$i], "\n";
		}
	}
	else {
		$content =~ s/\n*$//;
		print OUTPUTFILE "$content";
	}
	
	close(OUTPUTFILE);
}

method directory_above ( $directory ) {	
	my ($directory_above)		= $directory =~ /(.+)\/([^\/]+?)$/;
	
	return ($directory_above);
}

method split_path ( $filepath ) {
    my ($directory, $top) = $filepath =~ /(.+)\/([^\/]+?)$/;

    return ($directory, $top);
}


method datetime {
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime;
   
    $min = sprintf "%02d", $min;

    my $ampm = "AM";
    if ($hour > 12) {
        $hour = $hour - 12;
        $ampm = "PM";
    }

    my @Days = ("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday");
    my @Months = ("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December");
    
    my $day = $Days[$wday];
    my $month = $Months[$mon];
    my $date = $mday;
    
    $year = 1900 + $year;
    if ($year eq "1900") {
        $year = 2000 + $year;
    }
    
    my $datetime = "$hour:$min$ampm, $date $month $year";
    return $datetime;
}


method input2array ( $input_string ) {
	$input_string =~ s/^\s//g;
	my $input_array;
	
	while ( length($input_string) > 0 ) {
		if ( $input_string =~ /^(\d+)\-(\d+)/ ) {
			for ( my $i = $1; $i < $2 + 1; $i++ ) {
				push @$input_array, $i;
			}

			$input_string 	=~ s/^\d+\-\d+//;
		}
		elsif ( $input_string =~ /^(\d+)/ ) {
			push @$input_array, $1;
			$input_string 	=~ s/^\d+//;
			$input_string =~ s/^,//g;
		}
	}
	return $input_array;
}
    

method configfile ( $configfile ) {
	my $contents = Util::contents($configfile);
	if ( not defined $contents )	{	print "$0: Could not open config file '$configfile'\n\n";	}
	my ($database)  = $contents =~ /\n*\s*Database\s+(\w+)\s*\n/ims;
	my ($user)		= $contents =~ /\n*\s*User\s+(\w+)\s*\n/ims;
	my ($password)  = $contents =~ /\n*\s*Password\s+(\w+)\s*\n/ims;	
	
	return ($database, $user, $password);
}


method config_contents ( $configfile ) {
	open(FILE, $configfile) or die "Can't open config file '$configfile'\n";
	my $config_contents = '';
	while ( <FILE> ) {
		if ( $_ !~ /^\s*#/ )	{	$config_contents .= $_;	}
	}
	
	return $config_contents;
}

method sort_by_number ( $array ) {
	if ( not defined $array ) 	{	return;	}
	@$array = sort by_number @$array;
	
	return $array;
}

method by_number {
	my ($aa) = $a =~ /(\d+)/;
	my ($bb) = $b =~ /(\d+)/;
	
	$aa <=> $bb;
}


method sort_by_last_number ( $array ) {
	if ( not defined $array ) 	{	return;	}
	@$array = sort by_last_number @$array;
	
	return wantarray ? @$array : $array;
}
method by_last_number {
	my ($aa) = $a =~ /(\d+)\D*$/;
	my ($bb) = $b =~ /(\d+)\D*$/;
}



method sort_naturally ( $array ) {
	if ( not defined $array ) 	{	return;	}
	@$array = sort naturally @$array;
	
	return wantarray ? @$array : $array;
}

#### SORT BY NUMBER
#### 	- NUMBERS COME BEFORE LETTERS
#### 	- THEN SORT LETTERS BY cmp
method naturally {
	my ($aa) = $a =~ /(\d+)[^\/^\d]*$/;
	my ($bb) = $b =~ /(\d+)[^\/^\d]*$/;

	#### SORT BY NUMBER, OR cmp
	if ( defined $aa and defined $bb )	{	$aa <=> $bb	}
	elsif ( not defined $aa and not defined $bb )	{	$a cmp $b;	}
	elsif ( not defined $aa )	{	1;	}
	elsif ( not defined $bb )	{	-1;	}
}

method uppercase_firstletter ( $word ) {
    $word =~ /^(.)(.+)$/;
    $word = uc($1) . $2;
    
    return $word;
}

method block_text ( $text, $block_width, $split ) {
	$text =~ s/^\s*//;
	$text =~ s/\s*$//;
	
	my $block_text = '';
	if ( $split =~ /^word$/ ) {
		my @word_array = split " " , $text;
		
		#### RETURN LINE IF FIRST WORD IS TOO BIG FOR BLOCK WIDTH
		if ( length($word_array[0]) > $block_width )	{	return $text;	}

		#### OTHERWISE, SPLIT INTO BLOCKS
		while ( @word_array ) {
			my $line = '';
			while ( @word_array and ( length($line) + length($word_array[0]) ) < $block_width and ($#word_array + 1) > 0) {
				$line .= splice @word_array, 0, 1;
				$line .= " ";
			}
			$block_text .= "$line\n";
			if ( @word_array and length($word_array[0]) > $block_width )	{	return $block_text . $text;	}
		}
	}
	elsif ( $split =~ /^character$/i or $split =~ /^char$/i ) {
		while ( length($text) > $block_width ) {
			$block_text .= substr($text, 0, $block_width);
			$block_text .= "\n";
			$text = substr($text, $block_width);
		}
		if ( $text )	{	$block_text .= "$text\n";	}
		
	}
	$block_text =~ s/\n$//;
	
	return $block_text;	
}


method block_text_array ( $text, $block_width, $split ) {
	
	if ( not defined $block_width )	{	print ": Block width not defined\n\n";	exit;	}
	if ( not defined $split)	{	print "Split (word | char) not defined\n";	exit;	}
	
	$text =~ s/,$//;
	$text =~ s/^\s*//;
	$text =~ s/\s*$//;
	
	my $lines = 0;
	my $block_text_array;
	if ( $split =~ /^word$/ ) {
		my @word_array = split " " , $text;
		if ( not @word_array )	{	return;	}
		
		
		#### RETURN LINE IF FIRST WORD IS TOO BIG FOR BLOCK WIDTH
		if ( length($word_array[0]) > $block_width )	{	return $text;	}

		#### OTHERWISE, SPLIT INTO BLOCKS
		while ( @word_array ) {
			my $line = '';
		
			if ( $word_array[0] =~ /^[\[\]\(\)]*$/ )	{	splice @word_array, 0, 1;	}
			if ( not @word_array )	{	last;	}

			
			
			while ( @word_array
				   and ( length($line) + length($word_array[0]) ) <= $block_width
				   and ($#word_array + 1) > 0 ) {
				$line .= shift @word_array;
				$line .= " ";
				$lines++;
			}
			$line =~ s/\s$//;
			if ( $line )	{	push @$block_text_array, $line;	}

			
			#
			
			
			if ( @word_array and length($word_array[0]) > $block_width ) {				
				
				#### SPLIT THE LONG WORD AT A COMMA, IF AVAILABLE
				if ( length($word_array[0]) > $block_width
					   and $word_array[0] =~ /^(.+,)(\S+){1,$block_width}$/ ) {
					
					
					
				}

				#### SPLIT THE LONG WORD AT A HYPHEN, IF AVAILABLE
				elsif ( length($word_array[0]) > $block_width
					   and $word_array[0] =~ /^(.+\-)(\S+){1,$block_width}$/ ) {
					shift @word_array;
					unshift @word_array, $2;
					unshift @word_array, $1;					
				}

				#### SPLIT THE LONG WORD WITH A HYPHEN
				elsif ( length($word_array[0]) > $block_width
					   and $word_array[0] =~ /^(.+[aeiou][^a^e^i^o^u^y]{1,2})([^a^e^i^o^u^y]+[aeiou]\S+){1,$block_width}$/ ) {
					my $long_word = $word_array[0];
					my @array;
					while ( length($long_word) > $block_width
							and $long_word =~ /^(.+[aeiou][^a^e^i^o^u^y]{1,$block_width})([^a^e^i^o^u^y]+[aeiou]\S+){1,}$/ ) {
						push @array, "$1-";
					}
					push @array, 
					shift @word_array;
					@word_array = (@array, @word_array);
				}

				#### OTHERWISE CHOP THE LONG LINE AT A CHARACTER
				else {
					my $long_word_array = block_text_char($word_array[0], $block_width);
					shift @word_array;
					@word_array = (@$long_word_array, @word_array);
				}				
				
				#
			}
	
		}
			
	}
	elsif ( $split =~ /^character$/i or $split =~ /^char$/i ) {
		$block_text_array = block_text_char($text, $block_width);
	}
	
	return $block_text_array;	
}

method block_text_char ( $text, $block_width ) {
	my $block_text_array;
	while ( length($text) > $block_width ) {
		push @$block_text_array, substr($text, 0, 80);
		$text = substr($text, 80);
	}
	if ( $text ) {
		push @$block_text_array, $text;
	}

	return $block_text_array;
}


1;
