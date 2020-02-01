=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Versioning::Pipeline::Alignment

=head1 DESCRIPTION

Configures and runs Exonerate according to the chunk parameters given to it
Writes out RDF representing the alignments which make the quality thresholds

=cut

package Bio::EnsEMBL::Versioning::Pipeline::Alignment;

use strict;
use warnings;
use Bio::EnsEMBL::Mongoose::Utils::ExonerateAligner;
use Bio::EnsEMBL::Mongoose::Serializer::RDF;
use Bio::EnsEMBL::Utils::Exception;

use parent qw/Bio::EnsEMBL::Versioning::Pipeline::Base/;

sub fetch_input {
  my $self = shift;
  $self->param_required('max_chunks'); # how many fractions of the file are being worked on
  $self->param_required('chunk'); # which fraction of the file to process
  $self->param_required('source_file'); # Ensembl FASTA file
  $self->param_required('target_file'); # other FASTA file
  $self->param_required('align_method'); 
  $self->param_required('target_source'); # external source, e.g. RefSeq
  $self->param_required('output_path');
  $self->param_required('broker_conf');
}

sub run {
  my $self = shift;

  my $max_chunks = $self->param('max_chunks');
  my $chunk = $self->param('chunk');
  my $e_file = $self->param('source_file');
  my $other_file = $self->param('target_file');
  my $other_source = $self->param('target_source');
  my $seq_type = $self->param('seq_type');
  my $ensembl_source;
  if ($seq_type eq 'cdna') {
    $ensembl_source = 'ensembl_transcript';
  } elsif ($seq_type eq 'pep') {
    $ensembl_source = 'ensembl_protein';
  } else {
    $self->warning("Spurious sequence type requested in alignment: $seq_type");
  }

  my $fh = IO::File->new($self->param('output_path'),'w') or throw("Couldn't open". $self->param('output_path') ." for writing: $!\n");

  my $aligner = Bio::EnsEMBL::Mongoose::Utils::ExonerateAligner->new(
    chunk_cardinality => $max_chunks, 
    execute_on_chunk => $chunk,
    source => $other_file,
    target => $e_file
  );
  $aligner->set_method($self->param('align_method'));
  my $hits = $aligner->run;

  if (keys %$hits > 0) {
    my $writer = Bio::EnsEMBL::Mongoose::Serializer::RDF->new(handle => $fh, config_file => $self->param('broker_conf'));
    foreach my $alignment (keys %$hits) {
      my ($source_id,$target_id) = split /:/,$alignment;
      my $source_identity = $hits->{$alignment}->{query_identity};
      my $target_identity = $hits->{$alignment}->{target_identity};

      $writer->print_alignment_xrefs($source_id,$other_source,$target_id,$ensembl_source,$source_identity,'lot'.$chunk);
      $writer->print_alignment_xrefs($target_id,$ensembl_source,$source_id,$other_source,$target_identity,'lot'.$chunk);
    }
  }
  $fh->close;
}


1;
