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

Bio::EnsEMBL::Versioning::Pipeline::SeqTypeFactory

=head1 DESCRIPTION

Starting from a species and sequence type, this factory produces parameter pairings for dumping the 
right kinds of sequence from relevant sources for alignment
=cut

package Bio::EnsEMBL::Versioning::Pipeline::SeqTypeFactory;

use strict;
use warnings;

use parent qw/Bio::EnsEMBL::Versioning::Pipeline::Base/;

sub fetch_input {
  my $self = shift;
  $self->param_required('species');
  $self->param_required('seq_type');
  $self->param_required('fasta_path'); # Ensembl FASTA path needed downstream
}

sub run {
  my $self = shift;
  my $species = $self->param('species');
  my $seq_type = $self->param('seq_type');

  # abstract this to a conf file as required
  my @source_dumping_list = (
    ['RefSeq', 'cdna'],
    ['RefSeq', 'pep'],
    ['Swissprot', 'pep']
  );

  if ($species eq 'ciona_intestinalis') { push @source_dumping_list,['JGI','pep']}

  foreach my $source (grep { $_->[1] eq $seq_type} @source_dumping_list) {
    $self->dataflow_output_id({ 
      species => $species,
      source => $source->[0],
      seq_type => $seq_type,
      fasta_path => $self->param('fasta_path')
    } ,2);
  }
}

1;
