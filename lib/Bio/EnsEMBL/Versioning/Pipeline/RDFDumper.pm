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

Bio::EnsEMBL::Versioning::Pipeline::RDFDumper

=head1 DESCRIPTION

eHive pipeline module for RDF Xref Dumping

=cut

package Bio::EnsEMBL::Versioning::Pipeline::RDFDumper;

use strict;
use warnings;

use parent qw/Bio::EnsEMBL::Versioning::Pipeline::Base/;

use Bio::EnsEMBL::Mongoose::Persistence::LucyQuery;
use Bio::EnsEMBL::Mongoose::IndexSearch;
use Bio::EnsEMBL::Versioning::Broker;
use Bio::EnsEMBL::Mongoose::Persistence::QueryParameters;
use Bio::EnsEMBL::Mongoose::Serializer::RDF;
use IO::File;
use File::Spec;
use File::Path qw( make_path );
use Try::Tiny;
use Log::Log4perl;
Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");
use List::Compare;


sub run {
  my ($self) = @_;

  my $species = $self->param_required('species');
  my $run_id = $self->param_required('run_id');
  my $base_path = $self->param_required('base_path');
  
  my $broker = Bio::EnsEMBL::Versioning::Broker->new();

  my $valid_source_list = $broker->get_active_sources;
  $base_path ||= '/tmp';
  my $species_without_underscore = $species;
  $species_without_underscore =~ s/_/ /g;
  $base_path = File::Spec->join( $base_path, $run_id, "xref_rdf_dumps", $species);
  
  if (!-d $base_path) {
    make_path $base_path or die "Failed to create path: $base_path";
  }
  
  my $fh;
  my @final_source_list = map { $_->name } @$valid_source_list;
  foreach my $source (@final_source_list) {
  	print ("Source $source");
    $fh = IO::File->new(File::Spec->catfile($base_path,'xref',$self->param('run_id'),$self->param('species'),'xref_rdf_dumps',$source.'.ttl'), 'w') || die "Cannot write to $base_path: $!";
    try {
      my $searcher = Bio::EnsEMBL::Mongoose::IndexSearch->new(
        output_format => 'RDF',
        storage_engine_conf_file => $ENV{MONGOOSE}.'/conf/manager.conf',
        species => $species_without_underscore,
        handle => $fh,
      );
      
      #get version for a given run_id and source_name
      my $version = $broker->get_version_for_run_source($run_id,$source);
      
      $searcher->work_with_index(source => $source, version => $version->revision);
      $searcher->get_records();
      $fh->close;    
    } catch {
      warn('Warning ' . $_. ' while dumping RDF for source '.$source);
      $fh->close;
    };
}

  # Dump generic labels to attach to all possible sources for presentation. e.g. purl.uniprot.org/uniprot rdfs:label "Uniprot"
  my $source_fh = IO::File->new(File::Spec->catfile($base_path,'sources'.'.ttl'), 'w') || die "Cannot write to $base_path: $!";
  my $writer = Bio::EnsEMBL::Mongoose::Serializer::RDF->new(handle => $source_fh, config_file => "$ENV{MONGOOSE}/conf/manager.conf");
  $writer->print_source_meta;
  $source_fh->close;


}

1;
