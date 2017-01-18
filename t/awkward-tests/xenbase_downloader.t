use strict;
use warnings;

use Test::More;
use Test::Differences;
use Cwd;

use Bio::EnsEMBL::Versioning::Pipeline::Downloader::Xenbase;

use Log::Log4perl;

BEGIN {
  use FindBin qw/$Bin/;
  $ENV{MONGOOSE} = "$Bin/../..";
  $ENV{LOG} = "$Bin";
}

my $log_file = $ENV{LOG} . "/xenbase.t.log";
my $log_conf = <<"LOGCONF";
log4perl.logger=DEBUG, Screen, File

log4perl.appender.Screen=Log::Dispatch::Screen
log4perl.appender.Screen.layout=Log::Log4perl::Layout::PatternLayout
log4perl.appender.Screen.layout.ConversionPattern=%d %p> %F{1}:%L - %m%n

log4perl.appender.File=Log::Dispatch::File
log4perl.appender.File.filename=$log_file
log4perl.appender.File.mode=append
log4perl.appender.File.layout=Log::Log4perl::Layout::PatternLayout
log4perl.appender.File.layout.ConversionPattern=%d %p> %F{1}:%L - %m%n
LOGCONF

Log::Log4perl::init(\$log_conf);

use_ok 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::Xenbase';
my $xenbase = Bio::EnsEMBL::Versioning::Pipeline::Downloader::Xenbase->new();
isa_ok($xenbase, 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::Xenbase');

my $version = $xenbase->get_version;
note("Downloading Xenbase version (timestamp): " . $version);

my $result = $xenbase->download_to($Bin);
is($result->[0], "$Bin/GenePageEnsemblModelMapping.txt", 'Download of matching Xenbase file successful');

unlink $log_file;
unlink "$Bin/GenePageEnsemblModelMapping.txt";

done_testing;
