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

Bio::EnsEMBL::Versioning::Pipeline::AlignmentFactory

=head1 DESCRIPTION

Examines FASTA files to be compared and generates alignment jobs to process the results in reasonable parallelism

=cut

package Bio::EnsEMBL::Versioning::Pipeline::AlignmentFactory;

use strict;
use warnings;
use File::stat;
use Bio::EnsEMBL::Mongoose::Utils::AlignmentMethodFactory;
use Bio::EnsEMBL::Versioning::Broker;
use File::Path qw/make_path/;
use File::Spec;

use parent qw/Bio::EnsEMBL::Versioning::Pipeline::Base/;

sub fetch_input {
  my $self = shift;
  $self->param_required('xref_fasta');
  $self->param_required('seq_type');
  $self->param_required('species');
  $self->param_required('source');
  $self->param_required('run_id');
  $self->param_required('fasta_path');
}

sub run {
  my $self = shift;
  # inspect file size to decide on chunking
  my $seq_type = $self->param('seq_type'); # peptides or [r|d]na
  my $species = $self->param('species');
  my $source_file = $self->param('fasta_path'); # Get Ensembl FASTA path for this data type

  my $target_file = $self->param('xref_fasta'); # Get FASTA dumped from other source to align against
  my $size = stat($target_file)->size;
  my $chunks = int ($size / 1000000);
  
  my $method_factory = Bio::EnsEMBL::Mongoose::Utils::AlignmentMethodFactory->new();
  my $method = $method_factory->get_method_by_species_and_source($species,$self->param('source'));

  my $broker = Bio::EnsEMBL::Versioning::Broker->new();
  my $base_path = $broker->scratch_space;

  my $output_path = File::Spec->catfile($base_path,'xref',$self->param('run_id'),$species,'xref_rdf_dumps','alignment');
  make_path($output_path);

  for (my $chunklet = 1; $chunklet <= $chunks; $chunklet++) {
    $output_path .= sprintf "/%s_alignment_%s_of_%s.ttl",$self->param('source'),$chunklet,$chunks;
    $self->dataflow_output_id({
      align_method => $method, 
      max_chunks => $chunks, 
      chunk => $chunklet, 
      source_file => $source_file, 
      target_file => $target_file, 
      target_source => $self->param('source'),
      output_path => $output_path
    },2);
  }
}





1;