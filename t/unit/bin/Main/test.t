#!/usr/bin/perl -w

use Test::More tests => 2;
use Getopt::Long;
# plan skip_all => 'Onworking Util::Main tests';

use FindBin qw($Bin);
use lib "$Bin/../../lib";
use lib "$Bin/../../../../..";

use Conf::Yaml;
use Test::Util::Main;

#### CREATE OUTPUTS DIR
my $outputsdir = "$Bin/outputs";
`mkdir -p $outputsdir` if not -d $outputsdir;

#### GET OPTIONS
my $log   = 2;
my $printlog  = 5;
my $logfile = "/tmp/testuser.util.log";
my $help;
GetOptions (
    'log=i'         => \$log,
    'printlog=i'    => \$printlog,
    'logfile=s'     => \$logfile,
    'help'          => \$help
) or die "No options specified. Try '--help'\n";
usage() if defined $help;

#### SET CONF
my $configfile  =   "$Bin/../../../../../conf/config.yml";
my $conf = Conf::Yaml->new(
    memory      =>  1,
    inputfile   =>  $configfile,
    log         =>  $log,
    printlog    =>  $printlog,
    logfile     =>  $logfile
);

my $object = Test::Util::Main->new(
    conf        =>  $conf,
    logfile     =>  $logfile,
    log         =>	$log,
    printlog    =>  $printlog
);

#Completed running plugin: sge.CreateCell
$object->testFileTail();

