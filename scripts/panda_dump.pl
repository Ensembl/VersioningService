use Modern::Perl;
use strict;
use IO::File;
use Log::Log4perl;
use Bio::EnsEMBL::Mongoose::IndexSearch;
use Bio::EnsEMBL::Mongoose::Persistence::QueryParameters;
use Bio::EnsEMBL::Mongoose::Serializer::EnsemblRDF;

Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

my $base_path = $ENV{'HOME'}.'/projects/';
my $fh = IO::File->new("$base_path/panda_triples",'w');

my $species = 'ailuropoda melanoleuca';

my $extractor = Bio::EnsEMBL::Mongoose::IndexSearch->new(
  handle => $fh, 
  species => $species, 
  output_format => 'RDF', 
  source => 'UniProtSwissProt'
);

$extractor->work_with_index(source =>'UniProtSwissProt');
$extractor->get_records;


my $ens_writer = Bio::EnsEMBL::Mongoose::Serializer::EnsemblRDF->new(species => $species, handle => $fh);
$ens_writer->print_record;