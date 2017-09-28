use Modern::Perl;
use Test::More;
use Test::Differences;

use FindBin qw/$Bin/;
use lib "$Bin";
use TestDefaults;

use_ok 'Bio::EnsEMBL::Mongoose::Parser::SwissprotFaster';

# Uses uniprot BRAF record (P15056) to validate the Swissprot parser.
my $xml_reader = new Bio::EnsEMBL::Mongoose::Parser::SwissprotFaster(
    source_file => "$ENV{MONGOOSE}/t/data/braf.xml"
);

my $seq = "MAALSGGGGGGAEPGQALFNGDMEPEAGAGAGAAASSAADPAIPEEVWNIKQMIKLTQEHIEALLDKFGGEHNPPSIYLEAYEEYTSKLDALQQREQQLLESLGNGTDFSVSSSASMDTVTSSSSSSLSVLPSSLSVFQNPTDVARSNPKSPQKPIVRVFLPNKQRTVVPARCGVTVRDSLKKALMMRGLIPECCAVYRIQDGEKKPIGWDTDISWLTGEELHVEVLENVPLTTHNFVRKTFFTLAFCDFCRKLLFQGFRCQTCGYKFHQRCSTEVPLMCVNYDQLDLLFVSKFFEHHPIPQEEASLAETALTSGSSPSAPASDSIGPQILTSPSPSKSIPIPQPFRPADEDHRNQFGQRDRSSSAPNVHINTIEPVNIDDLIRDQGFRGDGGSTTGLSATPPASLPGSLTNVKALQKSPGPQRERKSSSSSEDRNRMKTLGRRDSSDDWEIPDGQITVGQRIGSGSFGTVYKGKWHGDVAVKMLNVTAPTPQQLQAFKNEVGVLRKTRHVNILLFMGYSTKPQLAIVTQWCEGSSLYHHLHIIETKFEMIKLIDIARQTAQGMDYLHAKSIIHRDLKSNNIFLHEDLTVKIGDFGLATVKSRWSGSHQFEQLSGSILWMAPEVIRMQDKNPYSFQSDVYAFGIVLYELMTGQLPYSNINNRDQIIFMVGRGYLSPDLSKVRSNCPKAMKRLMAECLKKKRDERPLFPQILASIELLARSLPKIHRSASEPSLNRAGFQTEDFSLYACASPKTPIQAGGYGAFPVH";

# read first record from XML
$xml_reader->read_record;

my $record = $xml_reader->record;

is($record->gene_name,"BRAF", 'gene_name attribute check');
is($record->primary_accession, "P15056", 'primary_accession check');
cmp_ok($record->taxon_id, '==', 9606, 'taxon_id check');
cmp_ok($record->sequence_length, '==', 766, 'sequence_length check');
is($record->sequence,$seq, 'Make sure sequence regex-trimming does no harm, but removes white space');
is($record->checksum, '74c9b69323bd112084c1b5b385e7e6c5', 'Verify checksum extraction');

cmp_ok($record->evidence_level, '==', 1, 'evidence level correctly extracted');
ok(!$record->suspicion, 'record should not be suspicious');

my @xrefs = @{ $record->xref };
my @go_xref = grep {$_->id eq 'GO:0005829'} @xrefs;
cmp_ok(scalar @go_xref, '==', 0, 'GO xrefs purposefully ignored');
# is($go_xref[0]->source,'GO','Check correct extraction of author of xref');

my @e_xref = grep {$_->id eq 'ENSP00000288602'} @xrefs;
cmp_ok(scalar @e_xref, '==', 1, 'A single Uniprot to Ensembl xref links ONLY to the protein');
@e_xref = grep {$_->id eq 'ENST00000288602'} @xrefs;
cmp_ok(scalar @e_xref, '==', 0, 'A single Uniprot to Ensembl xref links ONLY to the protein');


my $iso_list = $record->isoforms;
is_deeply($iso_list,['P66666-2'],'Isoform correctly identified and reported');

# Read second record from XML, this should be P0C8T7, with checksum AFF71E7E3DF6883D
$xml_reader->read_record;
$iso_list = $xml_reader->record->isoforms;
ok(!$iso_list,'No Isoform in second record, no problem');

is($xml_reader->record->checksum, '3a062f669941f083f7b8737b84f0eff3', 'Checksums still being caught');

# Read third record P84858
$xml_reader->read_record;

# Verify what happens when EOF is reached
ok(!$xml_reader->read_record, 'Check end-of-file behaviour. Reader should return false.');

done_testing;
