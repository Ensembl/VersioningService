use strict;
use warnings;

use FindBin qw/$Bin/;
use Log::Log4perl;


Log::Log4perl::init('$Bin/../conf/logger.conf');

use Bio::EnsEMBL::Mongoose::Parser::Swissprot;
use Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder;

my $parser = Bio::EnsEMBL::Mongoose::Parser::Swissprot->new( source_file => "/Users/ktaylor/projects/data/uniprot_sprot.xml" );
my $doc_store = Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder->new();

while ($parser->read_record) {
    my $record = $parser->record;
    printf "Main accession: %s, Gene name: %s, Taxon: %s\n",
    $record->primary_accession,$record->gene_name, $record->taxon_id;
    $doc_store->store_record($record);
};

$doc_store->commit;