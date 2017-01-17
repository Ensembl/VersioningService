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

my $log_file = $ENV{LOG} . "/mirbase.t.log";
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

use_ok 'Bio::EnsEMBL::Mongoose::Parser::MiRBase';

my $reader =
  Bio::EnsEMBL::Mongoose::Parser::MiRBase->new(source_file => "$ENV{MONGOOSE}/t/data/miRNA.dat.gz");
isa_ok($reader, 'Bio::EnsEMBL::Mongoose::Parser::MiRBase');

my $num_records = 0;

# check first record
$reader->read_record and ++$num_records;
my $record = $reader->record;
is($record->id, 'cel-let-7', 'First record ID');
is($record->display_label, 'cel-let-7', 'First record display label');
cmp_deeply($record->accessions, ['MI0000001'], 'First record accessions');
is($record->taxon_id, 6239, 'First record tax id');
my $expected_xrefs = [ bless( {
			       'source' => 'RFAM',
			       'creator' => 'MiRBase',
			       'active' => 1,
			       'id' => 'RF00027'
			      }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
		       bless( {
			       'source' => 'WORMBASE',
			       'creator' => 'MiRBase',
			       'active' => 1,
			       'id' => 'C05G5/12462-12364'
			      }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ) ];

cmp_deeply($record->xref, $expected_xrefs, 'First record xrefs');
is($record->sequence, 'TACACTGTGGATCCGGTGAGGTAGTAGGTTGTATAGTTTGGAATATTACCACCGGTGAACTATGCAATTTTCTACCTTACCGGAGACAGAACTCTTCGA', 'First record sequence');

# seek inside the file
$reader->read_record() and ++$num_records for 1 .. 60;
$record = $reader->record;
is($record->id, 'hsa-let-7b', 'Correct record ID');
is($record->display_label, 'hsa-let-7b', 'Correct record display label');
cmp_deeply($record->accessions, ['MI0000063'], 'Correct record accessions');
is($record->taxon_id, 9606, 'Correct record tax id');
$expected_xrefs = [ bless( {
			    'source' => 'RFAM',
			    'creator' => 'MiRBase',
			    'active' => 1,
			    'id' => 'RF00027'
			   }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
		    bless( {
			    'source' => 'HGNC',
			    'creator' => 'MiRBase',
			    'active' => 1,
			    'id' => '31479'
			   }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
		    bless( {
			    'source' => 'ENTREZGENE',
			    'creator' => 'MiRBase',
			    'active' => 1,
			    'id' => '406884'
			   }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ) ];
cmp_deeply($record->xref, $expected_xrefs, 'Correct record xrefs');
is($record->sequence, 'CGGGGTGAGGTAGTAGGTTGTGTGGTTTCAGGGCAGTGATGTTGCCCCTCGGAAGATAACTATACAACCTACTGCCTTCCCTG', 'Correct record sequence');

# read all the records until the end of the file
while ($reader->read_record()) {
  $record = $reader->record;
  ++$num_records;
}
ok(1, 'Reached end of file without dying');
is($num_records, 5883, "Successfully read all $num_records records from file");

unlink $log_file;

done_testing();
