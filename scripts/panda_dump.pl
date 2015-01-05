use Modern::Perl;
use strict;
use IO::File;
use Log::Log4perl;
use Bio::EnsEMBL::Mongoose::IndexSearch;
use Bio::EnsEMBL::Mongoose::Persistence::QueryParameters;
Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

my $base_path = $ENV{'PWD'};
my $fh = IO::File->new("$base_path/panda_triples",'w');

my $extractor = Bio::EnsEMBL::Mongoose::IndexSearch->new(
  handle => $fh, 
  species => 'ailuropoda melanoleuca', 
  output_format => 'RDF', 
  source => 'UniProtSwissProt'
);

$extractor->work_with_index(source =>'UniProtSwissProt');
$extractor->get_records;

