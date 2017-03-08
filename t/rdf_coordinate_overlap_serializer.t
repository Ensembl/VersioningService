use strict;
use Test::More;
#use Test::Deep;

use Bio::EnsEMBL::Mongoose::Serializer::RDFCoordinateOverlap;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use FindBin qw/$Bin/;
use IO::String;

my $dummy_content;
my $dummy_fh = IO::String->new($dummy_content);
my $rdf_writer = Bio::EnsEMBL::Mongoose::Serializer::RDFCoordinateOverlap->new(handle => $dummy_fh ,config_file => "$Bin/../conf/test.conf");

# Test record-writing powers

my $test_record = Bio::EnsEMBL::Mongoose::Persistence::Record->new({
  id => 'uc060qbx.1',
  accessions => [qw/uc060qbx.1/],
  });

$rdf_writer->print_coordinate_overlap_xrefs("ENST00000580678",$test_record,'ucsc_transcript',"0.823");

like( $dummy_content, '/ENST00000580678/', 'Have got ENST00000580678' );
like( $dummy_content, '/uc060qbx.1/', 'Have got uc060qbx.1' );
like( $dummy_content, '/0.823/', 'Have got 0.823' );


my $expected_content = '<http://rdf.ebi.ac.uk/resource/ensembl/ENST00000580678> <http://purl.org/dc/terms/source> <http://rdf.ebi.ac.uk/resource/ensembl/> .
<http://rdf.ebi.ac.uk/resource/ensembl/ENST00000580678> <http://purl.org/dc/elements/1.1/identifier> "ENST00000580678" .
<http://rdf.ebi.ac.uk/resource/ensembl/ENST00000580678> <http://www.w3.org/2000/01/rdf-schema#label> "ENST00000580678" .
<http://rdf.ebi.ac.uk/resource/ensembl/ENST00000580678> <http://rdf.ebi.ac.uk/terms/ensembl/refers-to> <http://rdf.ebi.ac.uk/resource/ensembl/xref/connection/ensembl/ucsc_transcript/1> .
<http://rdf.ebi.ac.uk/resource/ensembl/xref/connection/ensembl/ucsc_transcript/1> <http://rdf.ebi.ac.uk/terms/ensembl/refers-to> <http://rdf.ebi.ac.uk/resource/ensembl/xref/ucsc_transcript/uc060qbx.1> .
<http://rdf.ebi.ac.uk/resource/ensembl/xref/connection/ensembl/ucsc_transcript/1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://rdf.ebi.ac.uk/terms/ensembl/Coordinate_overlap> .
<http://rdf.ebi.ac.uk/resource/ensembl/xref/ucsc_transcript/uc060qbx.1> <http://purl.org/dc/elements/1.1/identifier> "uc060qbx.1" .
<http://rdf.ebi.ac.uk/resource/ensembl/xref/connection/ensembl/ucsc_transcript/1> <http://rdf.ebi.ac.uk/terms/ensembl/score> "0.823" .
';

ok($dummy_content eq $expected_content, "Contents are the same. Got back the right rdf output");
done_testing();