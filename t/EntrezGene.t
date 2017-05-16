use strict;
use Test::More;
use Test::Differences;
use Test::Deep;

use FindBin qw/$Bin/;
use lib "$Bin";
use TestDefaults;

use_ok 'Bio::EnsEMBL::Mongoose::Parser::EntrezGene';

my $reader = new Bio::EnsEMBL::Mongoose::Parser::EntrezGene(
    source_file => "$ENV{MONGOOSE}/t/data/gene_info.gz",
);

my $num_of_records = 0;
#first record
$reader->read_record;
my $record = $reader->record;
$num_of_records++;
is($record->id,'5692769','ID extraction from first record');

#check if the header line is read and the fields is initialized
my $fields = $reader->fields;
is(15, scalar(keys $fields), "Got back 15 columns as expected from gene_info file");
is(0, $fields->{'tax_id'}, "tax_id is the first column");
is(1, $fields->{'GeneID'}, "GeneID is the second column");
is(5, $fields->{'dbXrefs'}, "dbXrefs is the sixth column");

#next record
$reader->read_record;
$record = $reader->record;
$num_of_records++;
is($record->id,'1246500','ID extraction from second record');

#read all the records until the end of the file
while ($reader->read_record()) {
  $record = $reader->record;
  $num_of_records++;
 
}
ok(1, 'Reached end of gene_info.gz without dying');
ok(19 == $num_of_records, "Read all the 19 records from the file successfully");

#checking the last record 

#check if synonyms in the format => DSPS|SNAT
my @expected = qw(DSPS SNAT);
my $got = $record->synonyms;
isa_ok($got, 'ARRAY' );
cmp_deeply($got, \@expected, "Got back right synonym");


#check if xrefs in the format => MIM:600950|HGNC:HGNC:19|Ensembl:ENSG00000129673|HPRD:02974|Vega:OTTHUMG00000180179
my $expected_xref =         [
							bless( {
                                      'source' => 'MIM',
                                      'creator' => 'EntrezGene',
                                      'active' => 1,
                                      'id' => '600950'
                                    }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
                             bless( {
                                      'source' => 'HGNC',
                                      'creator' => 'EntrezGene',
                                      'active' => 1,
                                      'id' => 'HGNC:19'
                                    }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
                             bless( {
                                      'source' => 'Ensembl',
                                      'creator' => 'EntrezGene',
                                      'active' => 1,
                                      'id' => 'ENSG00000129673'
                                    }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
                             bless( {
                                      'source' => 'HPRD',
                                      'creator' => 'EntrezGene',
                                      'active' => 1,
                                      'id' => '02974'
                                    }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
                             bless( {
                                      'source' => 'Vega',
                                      'creator' => 'EntrezGene',
                                      'active' => 1,
                                      'id' => 'OTTHUMG00000180179'
                                    }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' )
                             ];    



my $all_xrefs = $record->xref;
isa_ok($all_xrefs, 'ARRAY' );
cmp_deeply($all_xrefs, $expected_xref, "Got back right xrefs");

#get the first xref and check if the object is right
my $first_xref = shift $all_xrefs;
isa_ok($first_xref, "Bio::EnsEMBL::Mongoose::Persistence::RecordXref");
ok('MIM' eq $first_xref->source, "xref source initialized properly");
ok('600950' eq $first_xref->id, "xref id initialized properly");
ok('EntrezGene' eq $first_xref->creator, "xref creator initialized properly");
ok('1' eq $first_xref->active, "xref id initialized properly");


done_testing;