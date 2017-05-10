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

use Bio::EnsEMBL::Utils::IO::FASTASerializer;
use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Versioning::Broker;
use File::Path qw/make_path/;
use File::Spec;
use IO::File;

use Digest::MD5 qw/md5_hex/;

sub fetch_input {
  my $self = shift;
  my $eg = $self->param('eg');
  
  # See Bio::EnsEMBL::Production::Pipeline::FASTA::DumpFile for determining whether we can reuse the previous release dumps
  # if($self->param('check_intentions')==1 && $self->param('requires_new_dna')==0){ 
  #    delete $sequence_types{'dna'};
  # }
  my $species = $self->param('species');

  my $broker = Bio::EnsEMBL::Versioning::Broker->new();
  my $base_path = $broker->scratch_space;
  # TODO - EG specific pathing suitable for their greater number of species
  foreach my $type (qw/cdna pep/) {
    my $full_path = File::Spec->catfile($base_path,'xref',$self->param('run_id'),$species,'fasta','ensembl',$type,'/');
    make_path($full_path);
    $self->param("${type}_path",$full_path);
  }

}

sub run {
  my ($self) = @_;
  # Check if dumping has been done for this run before, to speed up development by not having to re-dump sequence.
  my $cdna_path = $self->param('cdna_path').'transcripts.fa';
  my $pep_path = $self->param('pep_path').'peptides.fa';
  return if -e $cdna_path and -e $pep_path and -s $cdna_path and -s $pep_path; # Add a bypass to the process to force redumping over this

  my $fh = IO::File->new($cdna_path ,'w') || throw("Cannot create filehandle $cdna_path");
  my $fasta_writer = Bio::EnsEMBL::Utils::IO::FASTASerializer->new($fh);
  my $cdna_checksum_path = $self->param('cdna_path').'transcripts.md5';
  my $checksum_fh = IO::File->new($cdna_checksum_path ,'w') || throw("Cannot create filehandle ".$cdna_checksum_path);
  $self->param('cdna_checksum_path',$cdna_checksum_path);

  my $pep_fh = IO::File->new($pep_path ,'w') || throw("Cannot create filehandle $pep_path");
  my $pep_writer = Bio::EnsEMBL::Utils::IO::FASTASerializer->new($pep_fh);
  my $pep_checksum_path = $self->param('pep_path').'peptides.md5';
  my $pep_checksum_fh = IO::File->new($pep_checksum_path ,'w') || throw("Cannot create filehandle ".$pep_checksum_path);
  $self->param('pep_checksum_path', $pep_checksum_path);

  my $adaptor = $self->get_DBAdaptor('core');
  my $transcript_adaptor = $adaptor->get_adaptor('Transcript');
  my $transcript_list = $transcript_adaptor->fetch_all();
  while (my $transcript = shift @$transcript_list) {
    $fasta_writer->print_Seq($transcript->seq);
    printf $checksum_fh "%s\t%s\n",$transcript->stable_id,md5_hex($transcript->seq->seq);
    my $translation = $transcript->translate;
    if ($translation) {
      $pep_writer->print_Seq($translation);
      printf $pep_checksum_fh "%s\t%s\n",$transcript->stable_id,md5_hex($translation->seq);
    }
  }

  # Preserve the filenames for transcript and peptide fasta files for handing downstream to aligner
  $self->param('pep_file',$pep_path);
  $self->param('cdna_file',$cdna_path);

  $fh->close;
  $checksum_fh->close;
  $pep_fh->close;
  $pep_checksum_fh->close;

}

sub write_output {
  my ($self) = @_;

# Send checksum locations onto next process
  $self->dataflow_output_id({ 
    species => $self->param('species'), 
    cdna_path => $self->param('cdna_checksum_path'), 
    pep_path => $self->param('pep_checksum_path')
  }, 2);

  # Seed sequence types to per-species-per-xref-source FASTA dumping
  foreach my $type (qw/cdna pep/){
    $self->dataflow_output_id({ 
      species => $self->param('species'), 
      seq_type => $type ,
      fasta_path => $self->param("${type}_file")
    }, 3); 
  }


}

1;