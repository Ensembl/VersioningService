use Modern::Perl;
use IO::File;
use Log::Log4perl;
use Bio::EnsEMBL::Mongoose::IndexSearch;
use Bio::EnsEMBL::Mongoose::Persistence::QueryParameters;
use Bio::EnsEMBL::Mongoose::Serializer::RDF;

Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

my $base_path = $ENV{'HOME'}.'/test_rdf/';
my $fh = IO::File->new("$base_path/panda_triples.ttl",'w');

my $species = 'ailuropoda melanoleuca';

my $extractor = Bio::EnsEMBL::Mongoose::IndexSearch->new(
  handle => $fh, 
  species => $species, 
  output_format => 'RDF', 
  storage_engine_conf_file => $ENV{MONGOOSE}.'/conf/manager.conf'
);

$extractor->work_with_index(source =>'Swissprot');
$extractor->get_records;