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

Bio::EnsEMBL::Versioning::Pipeline::DumpEnsemblFASTA

=head1 DESCRIPTION

Produces FASTA dumps of cDNA and peptide sequence for use in alignment for xrefs
Also computes checksums while the sequences are handy

=cut

package Bio::EnsEMBL::Versioning::Pipeline::DumpEnsemblFASTA;

use strict;
use warnings;

use parent qw/Bio::EnsEMBL::Versioning::Pipeline::Base/;
use Bio::EnsEMBL::ApiVersion qw/software_version/;
use Bio::EnsEMBL::Utils::IO::FASTASerializer;
use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Versioning::Broker;
use File::Path qw/make_path/;
use File::Spec;
use IO::File;

use Digest::CRC;

sub fetch_input {
  my $self = shift;
  my $eg = $self->param('eg');
  my $release;
  if ($eg) {
     $release = $self->param('eg_version');
  } else {
    $release = software_version;
  }
  # See Bio::EnsEMBL::Production::Pipeline::FASTA::DumpFile for determining whether we can reuse the previous release dumps
  # if($self->param('check_intentions')==1 && $self->param('requires_new_dna')==0){ 
  #    delete $sequence_types{'dna'};
  # }
  my $species = $self->param('species');

  my $broker = Bio::EnsEMBL::Versioning::Broker->new();
  my $base_path = $broker->scratch_space;
  # TODO - EG specific pathing suitable for their greater number of species
  foreach my $type (qw/cdna pep/) {
    my $full_path = File::Spec->catfile($base_path,'xref',$release,$species,'fasta',$type,'/');
    make_path($full_path);
    $self->param("${type}_path",$full_path);
  }

}

sub run {
  my ($self) = @_;
  
  my $fh = IO::File->new($self->param('cdna_path').'transcripts.fa' ,'w') || throw("Cannot create filehandle ".$self->param('cdna').'transcripts.fa');
  my $fasta_writer = Bio::EnsEMBL::Utils::IO::FASTASerializer->new($fh);

  my $pep_fh = IO::File->new($self->param('pep_path').'peptides.fa' ,'w') || throw("Cannot create filehandle ".$self->param('cdna').'transcripts.fa');
  my $pep_writer = Bio::EnsEMBL::Utils::IO::FASTASerializer->new($pep_fh);

  my $adaptor = $self->get_DBAdaptor('core');
  my $transcript_adaptor = $adaptor->get_adaptor('Transcript');
  my $transcript_list = $transcript_adaptor->fetch_all();
  while (my $transcript = shift @$transcript_list) {
    $fasta_writer->print_Seq($transcript->seq);
    $pep_writer->print_Seq($transcript->translate) if $transcript->translate;
  }


  $fh->close;
  $pep_fh->close;

}

1;