=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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
use Bio::EnsEMBL::Mongoose::Taxonomizer;
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
  
  my $species_name = Bio::EnsEMBL::Mongoose::Taxonomizer->clean_species_name($species);
  
  my $full_path = File::Spec->join( $base_path, 'xref', $run_id, $species, "xref_rdf_dumps");
  my $transitive_path = File::Spec->join( $base_path, 'xref', $run_id, $species, "xref_rdf_dumps",'transitive');
  if (!-d $full_path) {
    make_path $full_path or die "Failed to create path: $full_path. $!";
  }
  if (!-d $transitive_path) {
    make_path $transitive_path or die "Failed to create path: $transitive_path. $!";
  }
  
  my $fh;
  my $transitive_fh;
  my $gene_fh;
  my @final_source_list = map { $_->name } @$valid_source_list;
  foreach my $source (@final_source_list) {
    $fh = IO::File->new(File::Spec->catfile($full_path,$source.'.ttl'), 'w') || die "Cannot write to $full_path: $!";
    $transitive_fh = IO::File->new(File::Spec->catfile($transitive_path,$source.'.ttl'), 'w') || die "Cannot write to $transitive_path: $!";
    my %search_conf = (
      output_format => 'RDF',
      species => $species_name,
      handle => $fh,
      writer_conf => { LOD_location => "$ENV{MONGOOSE}/conf/xref_LOD_mapping.json" }
    );
    if ($source =~ /RefSeq/i) {
      my $gene_model_path = File::Spec->join( $base_path, 'xref',$run_id,$species,'xref_rdf_dumps','gene_model','/'); # for RefSeq links to genes and proteins
      if (!-d $gene_model_path) { 
        make_path $gene_model_path or die "Failed to create path: $gene_model_path. $!";
      }
      $gene_fh = IO::File->new(File::Spec->catfile($gene_model_path,$source.'.ttl' ), 'w') || die "Cannot write to $gene_model_path: $!";
      $search_conf{other_handle} = $gene_fh;
    }
    try {
      my $searcher = Bio::EnsEMBL::Mongoose::IndexSearch->new(
        %search_conf
      );
      
      #get version for a given run_id and source_name
      my $version = $broker->get_version_for_run_source($run_id,$source);
      
      $searcher->work_with_index(source => $source, version => $version->revision);
      $searcher->get_records();
      $searcher->get_slimline_records($transitive_fh); # tell it to use another function
      $fh->close;
      $transitive_fh->close;
    } catch {
      $self->warning('Warning ' . $_. ' while dumping RDF for source '.$source);
      $fh->close;
    };
    # Now dumping twice per iteration, once to the "condensed" transitive graph of Direct-type xrefs
    # This could be done much more cleanly if the filehandle can be 
    # reset on $searcher and the nested RDF writer to print somewhere else. Currently 
    # the writer is configured to use a filehandle at $searcher instantiation, 
    # and not dynamically as it needs to be here. As a result I've had to clone
    # get_records to give a corresponding get_slimline_records()

}

  # Dump generic labels to attach to all possible sources for presentation. e.g. purl.uniprot.org/uniprot rdfs:label "Uniprot"
  my $source_fh = IO::File->new(File::Spec->catfile($full_path,'sources'.'.ttl'), 'w') || die "Cannot write to $full_path: $!";
  my $writer = Bio::EnsEMBL::Mongoose::Serializer::RDF->new(handle => $source_fh, config_file => $self->param('broker_conf'));
  $writer->print_source_meta;
  $source_fh->close;

  undef $gene_fh; # May or may not be open
}

1;
