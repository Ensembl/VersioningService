=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=pod


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Versioning::Pipeline::CheckCoordinateOverlap

=head1 DESCRIPTION

Checks for transcripts that overlap with ucsc transcripts based on coordinate position

=cut

package Bio::EnsEMBL::Versioning::Pipeline::CheckCoordinateOverlap;

use strict;
use warnings;

use parent qw/Bio::EnsEMBL::Versioning::Pipeline::Base/;

use Bio::EnsEMBL::Mongoose::Serializer::RDFCoordinateOverlap;
use Bio::EnsEMBL::Versioning::CoordinateMapper;
use Bio::EnsEMBL::ApiVersion qw/software_version/;
use File::Path qw/make_path/;
use File::Spec;
use IO::File;


sub fetch_input {
  my $self = shift;
  my $eg = $self->param('eg');
  my $release;
  if ($eg) {
     $release = $self->param('eg_version');
  } else {
    $release = software_version;
  }
  my $species = $self->param('species');
  
  # Derive location of coordinate_overlap
  my $indexer = Bio::EnsEMBL::Mongoose::IndexReader->new(species => $species);

  $self->param('indexer',$indexer);
  
  # Define where the RDF output will go and create the folder
  my $output_path = File::Spec->join( $self->param('base_path'), "xref_rdf_dumps", $self->param('run_id'), $species, 'coordinate_overlap');
  if (!-d $output_path) {
    make_path $output_path or die "Failed to create path: $output_path";
  }
  $self->param('output_path',$output_path);
}

sub run {
  my ($self) = @_;

  my $run_id = $self->param('run_id'); # Comes from hive param stack
  my $core_dba = $self->get_DBAdaptor('core');
  
  my $indexer = $self->param('indexer');
  my $output_path = $self->param('output_path');
  my $species= $self->param('species');
  
  my $broker = Bio::EnsEMBL::Versioning::Broker->new;
  my @sources = qw/refseq ucsc/;
  
  # Coordinate overlap is done only for refseq and ucsc
  foreach my $source(@sources){
    my $fh = IO::File->new($output_path.'/'.$source.'_coordinate_overlap.ttl','w') or throw("Failed to open ${source}_overlap.ttl for writing");
    my $rdf_writer = Bio::EnsEMBL::Mongoose::Serializer::RDFCoordinateOverlap->new(handle => $fh, config_file => $ENV{MONGOOSE}.'/conf/manager.conf');

    my $mapper = Bio::EnsEMBL::Versioning::CoordinateMapper->new;
    
    # for refseq we need to covert the rows from otherfeatures database to lucy index with coorinate info stored in the records. 
    # for UCSC, we already have the index with coordinate info
    if($source eq "refseq"){
      my $other_dba = $self->get_DBAdaptor('otherfeatures');
      next unless defined $other_dba;
      my $temp_index_folder = $mapper->create_temp_index({'species' => $species, 'dba' => $other_dba, 'analysis_name' => $source."_import"});
      if(defined $temp_index_folder && -e $temp_index_folder){
        $mapper->calculate_overlap_score({'index_location' => $temp_index_folder , 'species' => $species, 'core_dba' => $core_dba, 'other_dba' => $other_dba,'rdf_writer' => $rdf_writer , 'source' => $source});
      }
    }else{
      my $index_uri = $broker->get_index_by_name_and_version('UCSC');
      $mapper->calculate_overlap_score({'index_location' => $index_uri , 'species' => $species, 'core_dba' => $core_dba, 'rdf_writer' => $rdf_writer , 'source' => $source});
    }
  }
 
}


1;