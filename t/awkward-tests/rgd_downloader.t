use strict;
use warnings;

use Test::More;
use Test::Differences;
use Cwd;

use Bio::EnsEMBL::Versioning::Pipeline::Downloader::RGD;

use Log::Log4perl;

BEGIN {
  use FindBin qw/$Bin/;
  $ENV{MONGOOSE} = "$Bin/../..";
  $ENV{LOG} = "$Bin";
}

my $log_file = $ENV{LOG} . "/rgd.t.log";
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

use_ok 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::RGD';
my $rgd = Bio::EnsEMBL::Versioning::Pipeline::Downloader::RGD->new();
isa_ok($rgd, 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::RGD');

my $version = $rgd->get_version;
note("Downloading RGD version (timestamp): " . $version);

my $result = $rgd->download_to($Bin);
is($result->[0], "$Bin/GENES_RAT.txt", 'Download of matching RGD file successful');

unlink $log_file;
unlink "$Bin/GENES_RAT.txt";

done_testing;
