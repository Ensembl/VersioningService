use strict;
use warnings;

use Test::More;
use Test::Differences;
use Test::Deep;
use Log::Log4perl;

use Data::Dumper;

BEGIN {
  use FindBin qw/$Bin/;
  $ENV{MONGOOSE} = "$Bin/..";
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

use_ok 'Bio::EnsEMBL::Mongoose::Parser::UCSC';

my $reader =
  Bio::EnsEMBL::Mongoose::Parser::UCSC->new(source_file => "$ENV{MONGOOSE}/t/data/ucsc/hg38/knownGene.txt.gz");
isa_ok($reader, 'Bio::EnsEMBL::Mongoose::Parser::UCSC');

my $num_of_records = 0;

# check first record
$reader->read_record;
my $record = $reader->record;
++$num_of_records;
is($record->id, 'uc031tla.1', 'First record ID');
is($record->gene_name, 'uc031tla', 'First record gene name');
is($record->display_label, 'uc031tla', 'First record display label');
# is($record->taxon_id, 9606, 'Correct tax id');
my $xrefs = $record->xref;
my $expected_xrefs = [ bless( {
			       'source' => 'Ensembl',
			       'creator' => 'UCSC',
			       'active' => 1,
			       'id' => 'ENST00000619216.1'
			      }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ) ];
cmp_deeply($xrefs, $expected_xrefs, "First record xrefs");
my $xref = shift $xrefs;
isa_ok($xref, "Bio::EnsEMBL::Mongoose::Persistence::RecordXref");

unlink $log_file;

done_testing();
