use strict;
use warnings;

use Test::More;
use Test::Differences;
use Test::Deep;

use FindBin qw/$Bin/;
use lib "$Bin";
use TestDefaults;

use_ok 'Bio::EnsEMBL::Mongoose::Parser::Xenbase';

my $reader =
  Bio::EnsEMBL::Mongoose::Parser::Xenbase->new(source_file => "$ENV{MONGOOSE}/t/data/GenePageEnsemblModelMapping.txt");
isa_ok($reader, 'Bio::EnsEMBL::Mongoose::Parser::Xenbase');

my $num_of_records = 0;

note 'check first record';
$reader->read_record;
my $record = $reader->record;
++$num_of_records;
is($record->id, 'XB-GENE-478054', 'First record ID');
is($record->display_label, 'trnt1', 'First record display label');
is($record->gene_name, 'trnt1', 'First record gene name');
is($record->description, 'tRNA nucleotidyl transferase, CCA-adding, 1', 'First record description');
is($record->taxon_id, 8364, 'First record tax id');
my $xrefs = $record->xref;
my $expected_xrefs = [ bless( {
			       'source' => 'Ensembl',
			       'creator' => 'Xenbase',
			       'active' => 1,
			       'id' => 'ENSXETG00000025091'
			      }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ) ];
cmp_deeply($xrefs, $expected_xrefs, "First record xrefs");
my $xref = shift $xrefs;
isa_ok($xref, "Bio::EnsEMBL::Mongoose::Persistence::RecordXref");

note 'check intermediate record(s)';
for (1 .. 499) {
  $reader->read_record();
  ++$num_of_records;
}

my $expected = {
		id => 'XB-GENE-482885',
		display_label => 'pappa',
		gene_name => 'pappa',
		description => 'pregnancy-associated plasma protein A, pappalysin 1',
		xrefs => [ bless( {
				   'source' => 'Ensembl',
				   'creator' => 'Xenbase',
				   'active' => 1,
				   'id' => 'ENSXETG00000021730'
				  }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ) ]
	       };

my $got = $reader->record;
is($got->id, $expected->{id}, 'Correct record id');
is($got->display_label, $expected->{display_label}, 'Correct record display label');
is($got->gene_name, $expected->{gene_name}, 'Correct record gene name');
is($got->description, $expected->{description}, 'Correct record description');
is($got->taxon_id, 8364, 'Correct record tax id');
$xrefs = $got->xref;
cmp_deeply($got->xref, $expected->{xrefs}, "Correct xrefs");
$xref = shift $xrefs;
isa_ok($xref, "Bio::EnsEMBL::Mongoose::Persistence::RecordXref");

#read all the records until the end of the file
while ($reader->read_record()) {
  $record = $reader->record;
  ++$num_of_records;
}

ok(1, 'Reached end of file without dying');
is($num_of_records, 1000, "Successfully read all $num_of_records records from file");

done_testing();
