use Test::More;
use Test::Differences;

use Log::Log4perl;
Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

use Bio::EnsEMBL::Mongoose::Parser::Swissprot;

# Uses uniprot BRAF record (P15056) to validate the Swissprot parser.
my $xml_reader = new Bio::EnsEMBL::Mongoose::Parser::Swissprot(
    source_file => "data/braf.xml"
);

my $seq = "MAALSGGGGGGAEPGQALFNGDMEPEAGAGAGAAASSAADPAIPEEVWNIKQMIKLTQEHIEALLDKFGGEHNPPSIYLEAYEEYTSKLDALQQREQQLLESLGNGTDFSVSSSASMDTVTSSSSSSLSVLPSSLSVFQNPTDVARSNPKSPQKPIVRVFLPNKQRTVVPARCGVTVRDSLKKALMMRGLIPECCAVYRIQDGEKKPIGWDTDISWLTGEELHVEVLENVPLTTHNFVRKTFFTLAFCDFCRKLLFQGFRCQTCGYKFHQRCSTEVPLMCVNYDQLDLLFVSKFFEHHPIPQEEASLAETALTSGSSPSAPASDSIGPQILTSPSPSKSIPIPQPFRPADEDHRNQFGQRDRSSSAPNVHINTIEPVNIDDLIRDQGFRGDGGSTTGLSATPPASLPGSLTNVKALQKSPGPQRERKSSSSSEDRNRMKTLGRRDSSDDWEIPDGQITVGQRIGSGSFGTVYKGKWHGDVAVKMLNVTAPTPQQLQAFKNEVGVLRKTRHVNILLFMGYSTKPQLAIVTQWCEGSSLYHHLHIIETKFEMIKLIDIARQTAQGMDYLHAKSIIHRDLKSNNIFLHEDLTVKIGDFGLATVKSRWSGSHQFEQLSGSILWMAPEVIRMQDKNPYSFQSDVYAFGIVLYELMTGQLPYSNINNRDQIIFMVGRGYLSPDLSKVRSNCPKAMKRLMAECLKKKRDERPLFPQILASIELLARSLPKIHRSASEPSLNRAGFQTEDFSLYACASPKTPIQAGGYGAFPVH";


$xml_reader->read_record;

my $record = $xml_reader->record;

is($record->gene_name,"BRAF", 'gene_name attribute check');
is($record->primary_accession, "P15056", 'primary_accession check');
cmp_ok($record->taxon_id, '==', 9606, 'taxon_id check');
cmp_ok($record->sequence_length, '==', 766, 'sequence_length check');
is($record->sequence,$seq, 'Make sure sequence regex-trimming does no harm, but removes white space');

cmp_ok($record->evidence_level, '==', 1, 'evidence level correctly extracted');
ok(!$record->suspicion, 'record should not be suspicious');

my @xrefs = @{ $record->xref };
my @go_xref = grep {$_->id eq 'GO:0005829'} @xrefs;
cmp_ok(scalar @go_xref, '==', 1, 'GO xref found');
is($go_xref[0]->source,'GO','Check correct extraction of author of xref');

my $iso_list = $record->isoforms;
is_deeply($iso_list,['P66666-2'],'Isoform correctly identified and reported');

$xml_reader->read_record;
$iso_list = $xml_reader->record->isoforms;
ok(!$iso_list,'No Isoform in second record, no problem');
ok(!$xml_reader->read_record, 'Check end-of-file behaviour. Reader should return false.');


done_testing;