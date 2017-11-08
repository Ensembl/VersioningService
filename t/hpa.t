use strict;
use warnings;

use Test::More;
use Test::Differences;
use Test::Deep;

use FindBin qw/$Bin/;
use lib "$Bin";
use TestDefaults;

use_ok 'Bio::EnsEMBL::Mongoose::Parser::HPA';

my $reader =
  Bio::EnsEMBL::Mongoose::Parser::HPA->new(source_file => "$ENV{MONGOOSE}/t/data/protein_atlas.csv");
isa_ok($reader, 'Bio::EnsEMBL::Mongoose::Parser::HPA');

my $num_of_records = 0;

# check first record
$reader->read_record;
my $record = $reader->record;
++$num_of_records;
is($record->id, 1, 'First record ID');
is($record->display_label, 'CAB000001', 'First record display label');
is($record->taxon_id, 9606, 'Correct tax id');
my $xrefs = $record->xref;
my $expected_xrefs = [ bless( {
			       'source' => 'ensembl_protein',
			       'creator' => 'HPA',
			       'active' => 1,
			       'id' => 'ENSP00000363822'
			      }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ) ];
cmp_deeply($xrefs, $expected_xrefs, "First record xrefs");
my $xref = shift $xrefs;
isa_ok($xref, "Bio::EnsEMBL::Mongoose::Persistence::RecordXref");

# seek to the middle of the file
for (1 .. 59) {
  $reader->read_record();
  ++$num_of_records;
}

my @expected_records = (
		{
		 id => 13,
		 display_label => 'CAB000013',
		 xrefs => [ bless( {
				   'source' => 'ensembl_protein',
				   'creator' => 'HPA',
				   'active' => 1,
				   'id' => 'ENSP00000485791'
				  }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ) ]
		},
		{
		 id => 14,
		 display_label => 'CAB000014',
		 xrefs => [ bless( {
				   'source' => 'ensembl_protein',
				   'creator' => 'HPA',
				   'active' => 1,
				   'id' => 'ENSP00000351602'
				  }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ) ]
		},
		{
		 id => 15,
		 display_label => 'CAB000015',
		 xrefs => [ bless( {
				   'source' => 'ensembl_protein',
				   'creator' => 'HPA',
				   'active' => 1,
				   'id' => 'ENSP00000314620'
				  }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ) ]
		}
	       );

while ($num_of_records < 63) {
  $reader->read_record();
  my $got = $reader->record;
  ++$num_of_records;

  my $expected = shift @expected_records;
  is($got->id, $expected->{id}, 'Correct record id');
  is($got->display_label, $expected->{display_label}, 'First record display label');
  my $xrefs = $got->xref;
  cmp_deeply($got->xref, $expected->{xrefs}, "Correct xrefs");
}

#read all the records until the end of the file
while ($reader->read_record()) {
  $record = $reader->record;
  ++$num_of_records;
 
}

ok(1, 'Reached end of file without dying');
is($num_of_records, 99, "Successfully read all $num_of_records records from file");

done_testing();
