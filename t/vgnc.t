use strict;
use warnings;

use Test::More;
use Test::Differences;
use Test::Deep;

use FindBin qw/$Bin/;
use lib "$Bin";
use TestDefaults;

use_ok 'Bio::EnsEMBL::Mongoose::Parser::VGNC';

my $reader =
  Bio::EnsEMBL::Mongoose::Parser::VGNC->new(source_file => "$ENV{MONGOOSE}/t/data/chimpanzee_vgnc_gene_set_All.txt");
isa_ok($reader, 'Bio::EnsEMBL::Mongoose::Parser::VGNC');

my $num_of_records = 0;

# check first record
$reader->read_record;
my $record = $reader->record;

++$num_of_records;
is($record->id, 'VGNC:3019', 'First record ID');
is($record->primary_accession, 'VGNC:3019', 'First record accession');
is($record->display_label, 'ALKAL1', 'First record display label');
is($record->gene_name, 'ALK and LTK ligand 1', 'First record gene name');
is($record->taxon_id, 9598, 'Correct tax id');
cmp_deeply($record->synonyms, [ 'FAM150A' ], 'First record synonyms');
my $xrefs = $record->xref;
my $expected_xrefs = [ bless( {
			       'source' => 'Ensembl',
			       'creator' => 'VGNC',
			       'active' => 1,
			       'id' => 'ENSPTRG00000024172'
			      }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ) ];
cmp_deeply($xrefs, $expected_xrefs, "First record xrefs");
my $xref = shift $xrefs;
isa_ok($xref, "Bio::EnsEMBL::Mongoose::Persistence::RecordXref");

# seek to the middle of the file
for (1 .. 49) {
  $reader->read_record();
  ++$num_of_records;
}

my $expected = {
		id => 'VGNC:5662',
		display_label => 'ABCA3',
		gene_name => 'ATP binding cassette subfamily A member 3',
		synonyms => undef,
		taxon_id => 9598,
		xrefs => [ bless( {
				   'source' => 'Ensembl',
				   'creator' => 'VGNC',
				   'active' => 1,
				   'id' => 'ENSPTRG00000007647'
				  }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ) ]
	       };

my $got = $reader->record;

is($got->id, $expected->{id}, 'Correct record id');
is($got->primary_accession, $expected->{id}, 'Correct record primary accession');
is($got->display_label, $expected->{display_label}, 'Correct record display label');
is($got->gene_name, $expected->{gene_name}, 'Correct record gene name');
is($got->taxon_id, $expected->{taxon_id}, 'Correct record tax id');
cmp_deeply($got->synonyms, $expected->{synonyms}, 'Correct record synonyms');
$xrefs = $got->xref;
cmp_deeply($got->xref, $expected->{xrefs}, "Correct xrefs");

#read all the records until the end of the file
while ($reader->read_record()) {
  $record = $reader->record;
  ++$num_of_records; 
}

ok(1, 'Reached end of file without dying');
is($num_of_records, 100, "Successfully read all $num_of_records records from file");

done_testing();
