use strict;
use warnings;

use Test::More;
use Test::Differences;
use Test::Deep;
use Log::Log4perl;

use FindBin qw/$Bin/;
use lib "$Bin";
use TestDefaults;

use_ok 'Bio::EnsEMBL::Mongoose::Parser::UCSC';

my $reader =
  Bio::EnsEMBL::Mongoose::Parser::UCSC->new(source_file => "$ENV{MONGOOSE}/t/data/ucsc/hg38.txt.gz");
isa_ok($reader, 'Bio::EnsEMBL::Mongoose::Parser::UCSC');

my $num_of_records = 0;

# check first record
$reader->read_record;
my $record = $reader->record;
++$num_of_records;
is($record->id, 'uc031tla.1', 'First record ID');
is($record->taxon_id, 9606, 'First record tax ID');
is($record->gene_name, 'uc031tla', 'First record gene name');
is($record->display_label, 'uc031tla', 'First record display label');
is($record->chromosome, 1, 'Correct first record chromosome');
is($record->strand, -1, 'Correct first record strand');
is($record->transcript_start, 17369, 'Correct first record transcript start');
is($record->transcript_end, 17436, 'Correct first record transcript end');
is($record->cds_start, 0, 'Correct first record cds start');
is($record->cds_end, 0, 'Correct first record cds end');
cmp_deeply($record->exon_starts, [17369], 'Correct first record exon starts');
cmp_deeply($record->exon_ends, [17436], 'Correct first record exon ends');

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

# seek at some random point in the file
for (1 .. 118) {
  $reader->read_record();
  ++$num_of_records;
}

# uc057axr.1	chr1	-	917369	918534	917369	917369	2	917369,918021,	917486,918534,		ENST00000432961.1
# uc057axs.1	chr1	+	924879	939291	925941	939291	7	924879,925921,930154,931038,935771,939039,939274,	924948,926013,930336,931089,935896,939129,939291,	A6PWC8	ENST00000420190.5
# uc057axt.1	chr1	+	925149	935793	925941	935793	5	925149,925921,930154,931038,935771,	925189,926013,930336,931089,935793,	Q5SV95	ENST00000437963.5

my @expected_records = (
    {
     id => 'uc057axr.1',
     gene_name => 'uc057axr',
     display_label => 'uc057axr',
     chromosome => '1',
     strand => -1,
     transcript_start => 917370,
     transcript_end => 918534,
     cds_start => 0, # non coding transcripts have cds_start == cds_end and are set to null
     cds_end => 0,   #
     exon_starts => [917370, 918022],
     exon_ends => [917486, 918534],
     xrefs => [ bless( {
           'source' => 'Ensembl',
           'creator' => 'UCSC',
           'active' => 1,
           'id' => 'ENST00000432961.1'
          }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ) ]
    },
    {
     id => 'uc057axs.1',
     gene_name => 'uc057axs',
     display_label => 'uc057axs',
     chromosome => '1',
     strand => 1,
     transcript_start => 924880,
     transcript_end => 939291,
     cds_start => 925942,
     cds_end => 939291, 
     exon_starts => [924880, 925922, 930155, 931039, 935772, 939040, 939275],
     exon_ends => [924948, 926013, 930336, 931089, 935896, 939129, 939291],
     xrefs => [ bless( {
           'source' => 'UniProtKB',
           'creator' => 'UCSC',
           'active' => 1,
           'id' => 'A6PWC8'
           }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
          bless( {
            'source' => 'Ensembl',
            'creator' => 'UCSC',
            'active' => 1,
            'id' => 'ENST00000420190.5'
           }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' )]
    },
    {
     id => 'uc057axt.1',
     gene_name => 'uc057axt',
     display_label => 'uc057axt',
     chromosome => '1',
     strand => 1,
     transcript_start => 925150,
     transcript_end => 935793,
     cds_start => 925942, 
     cds_end => 935793, 
     exon_starts => [925150, 925922, 930155, 931039, 935772],
     exon_ends => [925189, 926013, 930336, 931089, 935793],
     xrefs => [ bless( {
           'source' => 'UniProtKB',
           'creator' => 'UCSC',
           'active' => 1,
           'id' => 'Q5SV95'
           }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
          bless( {
            'source' => 'Ensembl',
            'creator' => 'UCSC',
            'active' => 1,
            'id' => 'ENST00000437963.5'
           }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' )]
    }
         );

while ($num_of_records < 122) {
  $reader->read_record();
  my $got = $reader->record;
  ++$num_of_records;

  is($got->taxon_id, 9606, 'Correct record tax ID');
  
  my $expected = shift @expected_records;
  is($got->id, $expected->{id}, 'Correct record id');
  is($got->gene_name, $expected->{gene_name}, 'Correct record gene name');
  is($got->display_label, $expected->{display_label}, 'Correct record display label');
  is($got->chromosome, $expected->{chromosome}, 'Correct record chromosome');
  is($got->strand, $expected->{strand}, 'Correct record strand');
  is($got->transcript_start, $expected->{transcript_start}, 'Correct record transcript start');
  is($got->transcript_end, $expected->{transcript_end}, 'Correct record transcript end');
  is($got->cds_start, $expected->{cds_start}, 'Correct record cds start');
  is($got->cds_end, $expected->{cds_end}, 'Correct record cds end');
  cmp_deeply($got->exon_starts, $expected->{exon_starts}, 'Correct record exon starts');
  cmp_deeply($got->exon_ends, $expected->{exon_ends}, 'Correct record exon ends');
  my $xrefs = $got->xref;
  cmp_deeply($got->xref, $expected->{xrefs}, "Correct xrefs");
}

#read all the records until the end of the file
while ($reader->read_record()) {
  $record = $reader->record;
  ++$num_of_records; 
}

ok(1, 'Reached end of file without dying');
is($num_of_records, 10000, "Successfully read all $num_of_records records from file");

done_testing();
