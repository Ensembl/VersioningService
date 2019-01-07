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

Bio::EnsEMBL::Versioning::Pipeline::DumpEnsemblGeneModel

=head1 DESCRIPTION

Creates an RDF representation of the Ensembl gene-transcript-translation relation


=cut

package Bio::EnsEMBL::Versioning::Pipeline::DumpEnsemblGeneModel;

use strict;
use warnings;

use parent qw/Bio::EnsEMBL::Versioning::Pipeline::Base/;

use Bio::EnsEMBL::Mongoose::Serializer::RDF;
use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Versioning::Broker;
use File::Path qw/make_path/;
use File::Spec;
use IO::File;

sub fetch_input {
  my $self = shift;
  my $eg = $self->param('eg');
  my $species = $self->param_required('species');

  my $broker = Bio::EnsEMBL::Versioning::Broker->new();
  my $base_path = $broker->scratch_space;
  # TODO - EG specific pathing suitable for their greater number of species

  my $full_path = File::Spec->catfile($base_path,'xref',$self->param('run_id'),$species,'xref_rdf_dumps','gene_model','/');
  if (!-d $full_path) {
    make_path($full_path) || die "Failed to create path: $full_path. $!";
  }
  $self->param("ensembl_model_path",$full_path);
}

sub run {
  my ($self) = @_;

  my $path = $self->param("ensembl_model_path");
  my $fh = IO::File->new($path.'ensembl.ttl' ,'w') || throw("Cannot create filehandle $path");

  my $writer = Bio::EnsEMBL::Mongoose::Serializer::RDF->new(handle => $fh, config_file => $self->param('broker_conf'));
  my $adaptor = $self->get_DBAdaptor('core');
  my $gene_adaptor = $adaptor->get_adaptor('Gene');
  my $genes = $gene_adaptor->fetch_all;
  while (my $gene = shift @$genes) {
    my $transcripts = $gene->get_all_Transcripts;
    foreach my $transcript (@$transcripts) {
      my $translation = $transcript->translate;
      my ($translation_id,$translation_source);
      if ($translation) {
        $translation_id = $transcript->translation->stable_id;
        $translation_source = 'ensembl_protein';
      }
      $writer->print_gene_model_link($gene->stable_id,'ensembl',$transcript->stable_id,'ensembl_transcript',$translation_id,$translation_source);
    }
  }
}

1;
