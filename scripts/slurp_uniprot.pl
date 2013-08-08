use strict;
use warnings;

use Bio::EnsEMBL::Mongoose::Parser::Swissprot;
#use IO::File;

#my $fh = new IO::File "/Users/ktaylor/projects/data/uniprot_sprot.xml", "r" or die "unable to open. $@";

my $parser = Bio::EnsEMBL::Mongoose::Parser::Swissprot->new( source_file => "/Users/ktaylor/projects/data/uniprot_sprot.xml" );
while ($parser->read_record) {
    my $record = $parser->record;
    printf "Main accession: %s, Gene name: %s, Taxon: %s, Sequence length: %s\n",
    $record->primary_accession,$record->gene_name, $record->taxon_id, length($record->sequence);
};
