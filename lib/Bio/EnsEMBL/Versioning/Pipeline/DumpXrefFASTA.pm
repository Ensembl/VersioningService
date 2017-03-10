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

Bio::EnsEMBL::Versioning::Pipeline::DumpXrefFASTA

=head1 DESCRIPTION

Produces FASTA dumps of sequence from Xref sources that we have indexed
Normally used for RefSeq (transcript and protein), Uniprot proteins, miRBase transcripts and UniGene genes

=cut

package Bio::EnsEMBL::Versioning::Pipeline::DumpXrefFASTA;

use strict;
use warnings;

use parent qw/Bio::EnsEMBL::Versioning::Pipeline::Base/;
use Bio::EnsEMBL::ApiVersion qw/software_version/;
use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Versioning::Broker;
use Bio::EnsEMBL::Mongoose::IndexSearch;
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

  my $species = $self->param_required('species');
  my $run_id = $self->param_required('run_id');
  my $source = $self->param_required('source'); # as in RefSeq, or some other item that needs dumping
  my $seq_type = $self->param_required('seq_type'); # RNA, pep etc.

  my $broker = Bio::EnsEMBL::Versioning::Broker->new();
  my $base_path = $broker->scratch_space;

  my $full_path = File::Spec->catfile($base_path,'xref',$release,$species,'fasta',$source,$seq_type,'/');
  make_path($full_path);
  $self->param("path",$full_path);

}

sub run {
  my ($self) = @_;
  my $seq_type = $self->param('seq_type');
  my $source = $self->param('source');
  my $filename = $self->param('path').$seq_type.'.fa';

  my $fh = IO::File->new($filename ,'w');
    || throw("Cannot write to filehandle ".$filename);
  
  # Env variable to find conf file mid-pipeline should be removed
  my $search = Bio::EnsEMBL::Mongoose::IndexSearch->new(
    handle => $fh, 
    output_format => 'FASTA', 
    storage_engine_conf_file => $ENV{MONGOOSE}.'/conf/manager.conf', 
    species => $self->param('species')
  );
  $search->work_with_run($source,$self->param('run_id'));

  # Apply any source-specific filtering
  if ($source = 'RefSeq' && uc $seq_type eq 'rna') { 
    $search->filter(\&filter_refseq_rna);
  }
  if ($source = 'RefSeq' && uc $seq_type eq 'pep') { 
    $search->filter(\&filter_refseq_protein);
  }
  $search->get_records;
  $fh->close;
  $self->dataflow_output_id({ xref_fasta => $filename, source => $source, seq_type => $seq_type, species => $self->param('species') }, 2);
  
}

sub filter_refseq_rna {
  my $record = shift;
  return 1 if $record->id =~ /^[NX][RM]/; # Catches NM NR XM and XR
}
sub filter_refseq_protein {
  my $record = shift;
  return 1 if $record->id =~ /^\wP/; # Catches AP NP YP XP and ZP
}

1;