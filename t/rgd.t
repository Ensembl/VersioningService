use strict;
use warnings;

use Test::More;
use Test::Differences;
use Test::Deep;
use Log::Log4perl;

BEGIN {
  use FindBin qw/$Bin/;
  $ENV{MONGOOSE} = "$Bin/..";
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

use_ok 'Bio::EnsEMBL::Mongoose::Parser::RGD';

my $reader =
  Bio::EnsEMBL::Mongoose::Parser::RGD->new(source_file => "$ENV{MONGOOSE}/t/data/GENES_RAT.txt");
isa_ok($reader, 'Bio::EnsEMBL::Mongoose::Parser::RGD');

my $num_of_records = 0;

note 'check first record';
$reader->read_record;
my $record = $reader->record;
++$num_of_records;
is($record->id, 1594427, 'First record ID');
is($record->display_label, '2331ex4-5', 'First record display label');
is($record->gene_name, '2331ex4-5', 'First record gene name');
is($record->description, 'class I gene fragment 2331', 'First record description');
is($record->taxon_id, 10116, 'Correct tax id');
my $xrefs = $record->xref;
my $expected_xrefs = [ bless( {
			       'source' => 'RefSeq',
			       'creator' => 'RGD',
			       'active' => 1,
			       'id' => 'AABR07044364'
			      }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
		       bless( {
			       'source' => 'RefSeq',
			       'creator' => 'RGD',
			       'active' => 1,
			       'id' => 'AAHX01099425'
			      }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
		       bless( {
			       'source' => 'RefSeq',
			       'creator' => 'RGD',
			       'active' => 1,
			       'id' => 'BX883048'
			      }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
		       bless( {
			       'source' => 'RefSeq',
			       'creator' => 'RGD',
			       'active' => 1,
			       'id' => 'NG_004595'
			      }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ) ];
cmp_deeply($xrefs, $expected_xrefs, "First record xrefs");
my $xref = shift $xrefs;
isa_ok($xref, "Bio::EnsEMBL::Mongoose::Persistence::RecordXref");

note 'check intermediate record(s)';
for (1 .. 64) {
  $reader->read_record();
  ++$num_of_records;
}

my $expected = {
		id => 621583,
		display_label => 'A4galt',
		gene_name => 'A4galt',
		description => 'alpha 1,4-galactosyltransferase',
		synonyms => [ 'Gb3' ],
		xrefs => [ bless( {
				   'source' => 'RefSeq',
				   'creator' => 'RGD',
				   'active' => 1,
				   'id' => 'AAHX01051910'
				  }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
			   bless( {
				   'source' => 'RefSeq',
				   'creator' => 'RGD',
				   'active' => 1,
				   'id' => 'AC135486'
				  }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
			   bless( {
				   'source' => 'RefSeq',
				   'creator' => 'RGD',
				   'active' => 1,
				   'id' => 'AF248544'
				  }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
			   bless( {
				   'source' => 'RefSeq',
				   'creator' => 'RGD',
				   'active' => 1,
				   'id' => 'BC097323'
				  }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
			   bless( {
				   'source' => 'RefSeq',
				   'creator' => 'RGD',
				   'active' => 1,
				   'id' => 'CH473950'
				  }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
			   bless( {
				   'source' => 'RefSeq',
				   'creator' => 'RGD',
				   'active' => 1,
				   'id' => 'NM_022240'
				  }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
			   bless( {
				   'source' => 'RefSeq',
				   'creator' => 'RGD',
				   'active' => 1,
				   'id' => 'XM_006242117'
				  }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
			   bless( {
				   'source' => 'RefSeq',
				   'creator' => 'RGD',
				   'active' => 1,
				   'id' => 'XM_006242118'
				  }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
			   bless( {
				   'source' => 'RefSeq',
				   'creator' => 'RGD',
				   'active' => 1,
				   'id' => 'XM_017595078'
				  }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
			   bless( {
				   'source' => 'RefSeq',
				   'creator' => 'RGD',
				   'active' => 1,
				   'id' => 'XM_017595079'
				  }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
			   bless( {
				   'source' => 'RefSeq',
				   'creator' => 'RGD',
				   'active' => 1,
				   'id' => 'XM_017595080'
				  }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
			    bless( {
				    'source' => 'RefSeq',
				    'creator' => 'RGD',
				    'active' => 1,
				    'id' => 'XM_017595081'
				   }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
			   bless( {
				   'source' => 'Ensembl',
				   'creator' => 'RGD',
				   'active' => 1,
				   'id' => 'ENSRNOG00000009736'
				  }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ) ]
	       };

my $got = $reader->record;
++$num_of_records;

is($got->id, $expected->{id}, 'Correct record id');
is($got->display_label, $expected->{display_label}, 'Correct record display label');
is($got->gene_name, $expected->{gene_name}, 'Correct record gene name');
is($got->description, $expected->{description}, 'Correct record description');
cmp_deeply($got->synonyms, $expected->{synonyms}, 'Correct record synonyms');
$xrefs = $got->xref;
cmp_deeply($got->xref, $expected->{xrefs}, "Correct xrefs");

#read all the records until the end of the file
while ($reader->read_record()) {
  $record = $reader->record;
  ++$num_of_records;
}

ok(1, 'Reached end of file without dying');
is($num_of_records, 426, "Successfully read all $num_of_records records from file");

unlink $log_file;

done_testing();