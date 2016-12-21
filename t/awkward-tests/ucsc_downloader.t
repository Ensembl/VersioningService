use strict;
use warnings;

use Test::More;
use Test::Deep;
use Test::Differences;
use Cwd;

use Bio::EnsEMBL::Versioning::Pipeline::Downloader::UCSC;

use Log::Log4perl;

BEGIN {
  use FindBin qw/$Bin/;
  $ENV{MONGOOSE} = "$Bin/../..";
  $ENV{LOG} = "$Bin";
}

my $log_file = $ENV{LOG} . "/ucsc.t.log";
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

use_ok 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::UCSC';
my $ucsc = Bio::EnsEMBL::Versioning::Pipeline::Downloader::UCSC->new();
isa_ok($ucsc, 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::UCSC');

my $version = $ucsc->get_version;
note("Downloading UCSC version (timestamp): " . $version);

my $result = $ucsc->download_to($Bin);
my $expected = [ "$Bin/hg38.txt.gz", "$Bin/mm10.txt.gz"];
cmp_deeply($result, $expected, 'Download of matching UCSC files successful');

unlink $log_file;
unlink @{$expected};

done_testing;
