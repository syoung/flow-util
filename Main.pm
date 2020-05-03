use MooseX::Declare;
use Method::Signatures::Simple;

=head2

    PACKAGE        Util::Main
    
    PURPOSE
    
        UTILITY METHODS
        
=cut

class Util::Main with Util::Logger {

#### USE LIB FOR INHERITANCE
use FindBin qw($Bin);
use lib "$Bin/../../";

# Str
has 'sessionid'     => ( isa => 'Str|Undef', is => 'rw' );

# Object
has 'conf'            => ( 
    is => 'rw', 
    isa => 'Conf::Yaml', 
    lazy => 1, 
    builder => "setConf" 
);

method setConf {
    my $conf     = Conf::Yaml->new({
        backup        =>    1,
        log                =>    $self->log(),
        printlog    =>    $self->printlog()
    });
    
    $self->conf($conf);
}

=head2

    SUBROUTINE        getUserhome
    
    PURPOSE
    
        RETURN THE FULL PATH TO THE USER'S HOME DIR

=cut

method getUserhome ( $username ) {
    $self->logNote("username", $username);

    #### OTHERWISE, GET USERNAME FROM JSON IF NOT PROVIDED
    $username = $self->username() if not defined $username;
    return if not defined $username;

    my $userdir = $self->conf()->getKey("core:USERDIR");
    my $userhome = "$userdir/$username";
    
    return $userhome;    
}

=head2

    SUBROUTINE        getFileroot
    
    PURPOSE
    
        RETURN THE FULL PATH TO THE core.dir FOLDER WITHIN THE USER'S HOME DIR

=cut

method getFileroot ( $username ) {
    $self->logNote("username", $username);

    #### OTHERWISE, GET USERNAME FROM JSON IF NOT PROVIDED
    $username = $self->username() if not defined $username;
    return if not defined $username;

    my $userdir = $self->conf()->getKey("core:USERDIR");
    my $coredir = $self->conf()->getKey("core:DIR");
    my $fileroot = "$userdir/$username/$coredir";
    if ( $username eq "root" ) {
        $fileroot = "/$username/$coredir";
    }
    
    return $fileroot;    
}

method isTestUser ( $username ) {
    $self->logNote("username", $username);

    $username        =    $self->username() if not defined $username;
    if ( $self->can('requestor') ) {
        $username        =    $self->requestor() if $self->requestor();
    }
    $self->logNote("username", $username);

    my $testuser    =    $self->conf()->getKey("database:TESTUSER");
    $self->logNote("testuser", $testuser);

    return 0 if not defined $testuser;
    return 1 if defined $testuser and defined $username and $testuser eq $username;
    return 0;
}

#### SLOTS
method setSlots ($arguments) {
    #### ADD ARGUMENT VALUES TO SLOTS
    if ( $arguments )
    {
        foreach my $key ( keys %{$arguments} )
        {
            $arguments->{$key} = $self->unTaint($arguments->{$key});
            $self->$key($arguments->{$key}) if $self->can($key);
        }
    }    
}

#### PROCESSES
method killPid ($pid) {
#### KILL ALL PROCESSES ASSOCIATED WITH THE
#### PROCESS ID AND RETURN ANY RESULTING STDOUT

    $self->logDebug("pid", $pid);
    return if not defined $pid or not $pid;

    my $command = $self->killPidsCommand($pid);
    $self->logDebug("command", $command);
    return if not defined $command;
    
    my $output = `$command`;
    $self->logDebug("output", $output);
    
    return $output;
}

method killPidsCommand ($pid) {
    $self->logDebug("pid", $pid);

    return if not defined $pid or not $pid;

    my $lines = $self->getProcessTree($pid);
    $self->logDebug("lines", $lines);
    return if not defined $lines or not @$lines;

    my $pids = $self->getProcessPids($lines);
    $self->logDebug("pids", $pids);
    
    my $command = "kill -9 @$pids";
    $self->logDebug("command", $command);
    
    return $command;
}

method getProcessPids ($lines) {
    my $pids = [];
    foreach my $line ( @$lines ) {
        $line =~ /^\s*\d+\s+(\d+)\s+/;
        push @$pids, $1;
    }
    
    return $pids;
}

method getProcessTree ($pid) {
#### RETURN AN ARRAY OF LINES BELONGING
#### TO THE PROCESS TREE OF THE INPUT PID
    my $ps = $self->getProcessTrees();
    $self->logDebug("ps", $ps);
    
    #### REMOVE LINES PRECEDING PROCESS TREE
    my @lines = split "\n", $ps;
    for ( my $i = 0; $i < $#lines + 1; $i++ ) {
        if ( $lines[$i] !~ /^\s*\d+\s+$pid\s+/ ) {
            splice @lines, $i, 1;
            $i--;
        }
        else {
            last;
        }
    }
    #$self->logDebug("REMOVED PRECEDING lines", \@lines);    
    
    #### REMOVE LINES AFTER PROCESS TREE
    my $pids = ["$pid"];
    my $end = 0;
    for ( my $i = 1; $i < $#lines + 1; $i++ ) {
        my $line = $lines[$i];
        $self->logDebug("line", $line);
        my $matched = 0;
        foreach my $pid ( @$pids ) {
            #$self->logDebug("CHECKING pid", $pid);
            if ( $line =~ /^\s*$pid\s+(\d+)\s+/ ) {
                #$self->logDebug("MATCHED AT i: $i");
                push (@$pids, $1);
                $matched = 1;
                last;
            }
        }
        last if not $matched;
        $end = $i;
    }
    #$self->logDebug("PRE-FINAL lines", \@lines);
    #$self->logDebug("end", $end);
    #### REMOVE REMAINING LINES IF NOT END OF LINES
    splice(@lines, $end + 1) if ($end + 1) < $#lines + 1;
    $self->logDebug("FINAL lines", \@lines);
    $self->logDebug("FINAL pids", $pids);
    
    return \@lines;
}

method getProcessTrees {
    return `ps axjf`;
}

#### ARRAYS
method objectInArray {
    return 1 if defined $self->_indexInArray(@_);
    
    return 0;
}

method _indexInArray ($array, $object, $keys) {
    return if not defined $array or not defined $object;
    for ( my $i = 0; $i < @$array; $i++ )
    {
        my $identified = 1;
        for ( my $j = 0; $j < @$keys; $j++ )
        {
            if ( not defined $object
                or not defined $object->{$$keys[$j]}
                or defined $$array[$i]->{$$keys[$j]} xor defined $object->{$$keys[$j]}
                or $$array[$i]->{$$keys[$j]} ne $object->{$$keys[$j]} ) {
                $identified = 0; 
            }
        }
        return $i if $identified;
    }
    
    return;
}


method parseHash ($json) {
=head2

    SUBROUTINE        parseHash
    
    PURPOSE

        HASH INTO ARRAY OF TAB-SEPARATED KEY PAIRS

=cut
    #### INITIATE JSON PARSER
    use JSON -support_by_pp; 
    my $jsonParser = JSON->new();

    my $outputs = [];
    
    if ( defined $json )
    {
        my $hash = $jsonParser->decode($json);
        my @keys = keys %$hash;
        @keys = sort @keys;

        foreach my $key ( @keys )
        {
            my $value = $hash->{$key}->{value};
            if ( defined $value and $value )
            {
                push @$outputs, "$key\t$value\n";    
            }
        }
    }

    return $outputs;
}

method hasharrayToHash ($hasharray, $key) {
    $self->logError("hasharray not defined.") and return if not defined $hasharray;
    $self->logError("key not defined.") and return if not defined $key;

    my $hash = {};
    foreach my $entry ( @$hasharray )
    {
        my $key = $entry->{$key};
        if ( not exists $hash->{$key} )
        {
            $hash->{$key} = [ $entry ];
        }
        else
        {
            push @{$hash->{$key}}, $entry;
        }
    }

    return $hash;
}

#### DIRECTORIES
method createDir ($directory) {
    $self->logNote("directory", $directory);
    `mkdir -p $directory`;
    $self->logError("Can't create directory: $directory") and exit if not -d $directory;
    
    return $directory;
}

method getDirs ($directory) {
    $self->logDebug("directory", $directory);
    
    opendir(DIR, $directory) or $self->logError("Can't open directory: $directory") and exit;
    my $dirs;
    @$dirs = readdir(DIR);
    closedir(DIR) or die "Can't close directory: $directory";
    $self->logNote("RAW dirs", $dirs);
    
    for ( my $i = 0; $i < @$dirs; $i++ ) {
        if ( $$dirs[$i] =~ /^\.+$/ ) {
            splice @$dirs, $i, 1;
            $i--;
        }
    }
    
    for ( my $i = 0; $i < @$dirs; $i++ ) {
        last if scalar(@$dirs) == 0 or $dirs == [];
        my $filepath = "$directory/$$dirs[$i]";
        if ( not -d $filepath ) {
            splice @$dirs, $i, 1;
            $i--;
        }
    }
    $self->logNote("FINAL dirs", $dirs);
    
    return $dirs;    
}

method getFileDirs ($directory) {
    $self->logDebug("directory", $directory);
    
    my $filedirs;
    opendir(DIR, $directory) or $self->logError("Can't open directory: $directory") and exit;
    @$filedirs = readdir(DIR);
    closedir(DIR) or die "Can't close directory: $directory";
    
    for ( my $i = 0; $i < @$filedirs; $i++ ) {
        if ( $$filedirs[$i] =~ /^\.+$/ ) {
            splice @$filedirs, $i, 1;
            $i--;
        }
    }
    
    return $filedirs;    
}

method createParentDir ($file) {
    #### CREATE DIR IF NOT PRESENT
    my ($directory) = $file =~ /^(.+?)\/[^\/]+$/;
    $self->logDebug("directory", $directory);
    `mkdir -p $directory` if $directory and not -d $directory;
    
    return -d $directory;
}

#### FILES
method getFilesByRegex ($directory, $regex) {
    my $files    =    $self->getFiles($directory);
    for ( my $i = 0; $i < @$files; $i++ ) {
        if ( $$files[$i] !~ /$regex/ ) {
            splice (@$files, $i, 1);
            $i--;
        }
    }

    return $files;
}

method getFiles ($directory) {
    opendir(DIR, $directory) or $self->logDebug("Can't open directory", $directory);
    my $files;
    @$files = readdir(DIR);
    closedir(DIR) or $self->logDebug("Can't close directory", $directory);

    for ( my $i = 0; $i < @$files; $i++ ) {
        if ( $$files[$i] =~ /^\.+$/ ) {
            splice @$files, $i, 1;
            $i--;
        }
    }

    for ( my $i = 0; $i < @$files; $i++ ) {
        my $filepath = "$directory/$$files[$i]";
        if ( not -f $filepath ) {
            splice @$files, $i, 1;
            $i-- 
        }
    }

    return $files;
}

method getFileContents ($file) {
    $self->logNote("file", $file);
    open(FILE, $file) or $self->logCritical("Can't open file: $file") and exit;
    my $temp = $/;
    $/ = undef;
    my $contents =     <FILE>;
    close(FILE);
    $/ = $temp;

    return $contents;
}


method setPermissions ($username, $filepath) {
    #### SET OWNERSHIP
    my $apache_user = $self->conf()->getKey("core:APACHEUSER");
    $self->logDebug("apache_user", $apache_user);
    my $chown = "chown -R $username:$apache_user $filepath &> /dev/null";
    $self->logDebug("chown", $chown);
    print `$chown`;

    #### SET PERMISSIONS
    my $chmod = "find $filepath -type d -exec chmod 0775 {} \\;;";
    $self->logDebug("chmod", $chmod);
    print `$chmod`;
    $chmod = "find $filepath -type f -exec chmod 0664 {} \\;;";
    $self->logDebug("chmod", $chmod);
    print `$chmod`;
}

method incrementFile ($file) {
    $self->logDebug("file", $file);

    $file .= ".1";
    return $file if not -f $file and not -d $file;
    my $is_file = -f $file;
    
    if ( $is_file and $self->foundFile($file)
        or not $is_file and $self->foundDir($file) )
    {
        my ($stub, $index) = $file =~ /^(.+?)\.(\d+)$/;
        $index++;
        $file = $stub . "." . $index;
    }

    $self->logDebug("Returning file", $file);
    return $file;    
}

method fileTail ($file, $found, $pause, $maxwait) {

    $pause = 1 if not defined $pause;
    $maxwait = 1 if not defined $maxwait;
    $self->logDebug("file", $file);
    $self->logDebug("found", $found);
    $self->logDebug("pause", $pause);
    $self->logDebug("maxwait", $maxwait);
    
    my $elapsed = 0;
    my $time = time();

    #### WAIT UNTIL FILE APPEARS
    while ( not -f $file ) {
        # SLEEP AND ELAPSED
        sleep($pause);
        $elapsed = time() - $time ;
        return 0 if $elapsed > $maxwait;
    }

    open(FILE, $file);
    my $curpos;
    for (;;) {
        for ( $curpos = tell(FILE); <FILE>; $curpos = tell(FILE) ) {
            $self->logDebug("FOUND IN LINE: $_") if $_ =~ /$found/;
            return 1 if $_ =~ /$found/;
            $time = time();
        }

        # SLEEP AND ELAPSED
        sleep($pause);
        $elapsed = time() - $time ;
        return 0 if $elapsed > $maxwait;

        seek(FILE, $curpos, 0);  # SEEK BACK TO LAST POSITION
    }

    return 0;
}

#### LINE METHODS
method getLines ($file) {
    $self->logDebug("file", $file);
    $self->logWarning("file not defined") and return if not defined $file;
    my $temp = $/;
    $/ = "\n";
    open(FILE, $file) or $self->logCritical("Can't open file: $file\n") and exit;
    my $lines;
    @$lines = <FILE>;
    close(FILE) or $self->logCritical("Can't close file: $file\n") and exit;
    $/ = $temp;
    
    for ( my $i = 0; $i < @$lines; $i++ ) {
        if ( $$lines[$i] =~ /^\s*$/ ) {
            splice @$lines, $i, 1;
            $i--;
        }
    }
    
    return $lines;
}

method printToFile ($file, $text) {
    $self->logDebug("file", $file);

    $self->createParentDir($file);
    
    #### PRINT TO FILE
    open(OUT, ">$file") or $self->logCaller() and $self->logCritical("Can't open file: $file") and exit;
    print OUT $text;
    close(OUT) or $self->logCaller() and $self->logCritical("Can't close file: $file") and exit;    
}

#### I/O
method captureStderr ($command) {
    $self->logDebug("command", $command);

    my $tempfile = "/tmp/$$.command.stderr";
    $self->logDebug("tempfile", $tempfile);
    `$command 2> $tempfile`;
    my $output = `cat $tempfile`;
    $self->logDebug("output", $output);
    `rm -fr $tempfile`;
    
    return $output;
}

#### VARIABLES
method addEnvars ($string) {

    my $args = {
        project        =>    $self->project(),
        workflow    =>    $self->workflow(),
        username    =>    $self->username()
    };
    
    return $self->systemVariables($string, $args);
}

#### INSERT OPTIONAL SYSTEM VARIABLES BRACKETED BY '%', E.G., %project%
method systemVariables ($string, $args) {
    $string =~ s/%username%/$args->{username}/g if defined $args->{username};
    $string =~ s/%project%/$args->{project}/g if defined $args->{project};
    $string =~ s/%workflow%/$args->{workflow}/g if defined $args->{workflow};
    $string =~ s/%workflownumber%/$args->{workflownumber}/g if defined $args->{workflownumber};

    $self->logDebug("returning string", $string);

    return $string;
}

#### TEXT
method json_parser {
=head2

    SUBROUTINE        json_parser
    
    PURPOSE
    
        RETURN A JSON PARSER OBJECT
        
=cut    
    return $self->jsonparser() if $self->can('jsonparser') and $self->jsonparser();
    
    use JSON -support_by_pp; 
    my $jsonparser = JSON->new();
    $self->jsonparser($jsonparser) if $self->can('jsonparser');

    return $jsonparser;
}


method cowCase ($string) {
    return uc(substr($string, 0, 1)) . substr($string, 1);
}

method collapsePath ($string) {
    return if not defined $string;
    
    while ($string =~ s/\/[^\/^\.]+\/\.\.//g ) { }
    
    return $string;
}

#### DATETIME
method datetime {
=head2

    SUBROUTINE        datetime
    
    PURPOSE

        RETURN THE CURRENT DATE AND TIME

=cut
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime();
    $sec = sprintf "%02d", $sec;
    $min = sprintf "%02d", $min;
    $hour = sprintf "%02d", $hour;
    $mday = sprintf "%02d", $mday;
    $mon = sprintf "%02d", $mon;
    $year -= 100;
    $year = sprintf "%02d", $year;
    my $datetime = "$year-$mon-$mday-$hour-$min-$sec";

    return $datetime;
}

#### UNTAINT
method unTaint ($input) {
    return if not defined $input;
    
    $input =~ s/;.*$//g;
    $input =~ s/`.*$//g;
    
    return $input;
}

method addHashes ($hash1, $hash2) {
    foreach my $key ( keys %$hash2 ) {
        $hash1->{$key}    =    $hash2->{$key};
    }
    
    return $hash1;
}

method queueName ($username, $project, $workflow) {
    return if not defined $username or not defined $project or not defined $workflow;
    return "$username-$project-$workflow";    
}

#### JSON METHODS
method setJsonParser {
    return JSON->new->allow_nonref;
}

#### JSON
method jsonToObject ($json) {
    my $parser        =    $self->jsonparser();
    
    return $parser->decode($json);
}
method jsonFileToObject ($jsonfile) {
    my $contents     =    $self->getFileContents($jsonfile);
    my $parser         =     $self->jsonparser();

    return $parser->decode($contents);
}

#### CONFIG FILE
method setConf {
    my $conf     = Conf::Yaml->new({
        backup        =>    1,
        log            =>    $self->log(),
        printlog    =>    $self->printlog()
    });
    
    $self->conf($conf);
}

#### ENVAR
method setEnvar {
    my $customvars    =    $self->can("customvars") ? $self->customvars() : undef;
    my $envarsub    =    $self->can("envarsub") ? $self->envarsub() : undef;
    $self->logDebug("customvars", $customvars);
    $self->logDebug("envarsub", $envarsub);
    
    my $envar = Envar->new({
        db            =>    $self->table()->db(),
        conf        =>    $self->conf(),
        customvars    =>    $customvars,
        envarsub    =>    $envarsub,
        parent        =>    $self
    });
    
    $self->envar($envar);
}

#### SORTING
method sortByRegex ($array, $regex) {
    return if not defined $array;
    
    my $byRegex = sub {
        my ($aa) = $a =~ /(\d+)/;
        my ($bb) = $b =~ /(\d+)/;
        
        $aa <=> $bb;
    };
    
    @$array = sort $byRegex @$array;
    
    return $array;
}

method byRegex {
    my ($aa) = $a =~ /(\d+)/;
    my ($bb) = $b =~ /(\d+)/;
    
    $aa <=> $bb;
}

method sortByNumber ($array) {
    my $numbersort    =    method {
        my ($aa) = $a =~ /(\d+)/;
        my ($bb) = $b =~ /(\d+)/;
    
        $aa <=> $bb;
    };
    
    @$array    =    sort $numbersort @$array;
    
    return $array;
}


}

1;
