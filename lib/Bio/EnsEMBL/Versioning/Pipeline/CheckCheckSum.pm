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

Bio::EnsEMBL::Versioning::Pipeline::CheckCheckSum

=head1 DESCRIPTION

Takes a checksum file containing MD5s and searches through all relevant indexes,
before producing RDF links to represent the xrefs that are found.

=cut

package Bio::EnsEMBL::Versioning::Pipeline::CheckCheckSum;

use strict;
use warnings;

use parent qw/Bio::EnsEMBL::Versioning::Pipeline::Base/;

use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Versioning::Broker;
use Bio::EnsEMBL::Mongoose::Persistence::QueryParameters;
use Bio::EnsEMBL::Mongoose::IndexReader;
use Bio::EnsEMBL::Mongoose::Serializer::RDF;
use Bio::EnsEMBL::ApiVersion qw/software_version/;
use File::Path qw/make_path/;
use File::Spec;
use IO::File;
use Bio::EnsEMBL::Utils::IO qw/slurp_to_array/;

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

  $self->param_required('cdna_checksum_path');
  $self->param_required('pep_checksum_path');
  
  # Define where the RDF output will go and create the folder
  my $output_path = File::Spec->join( $self->param('base_path'), 'xref',$self->param('run_id'), $species, 'xref_rdf_dumps','checksum');
  if (!-d $output_path) {
    make_path $output_path or die "Failed to create path: $output_path";
  }
  $self->param('output_path',$output_path);
}

sub run {
  my ($self) = @_;

  my $run_id = $self->param('run_id'); # Comes from hive param stack
  
  my %ens_checksum;
  # convert Ensembl ID\tchecksum into () id1 => checksum1, ...)
  my %transcript_checksum;
  my %peptide_checksum;
  foreach my $path (qw/cdna_checksum_path pep_checksum_path/) {
    my $checksum_hash;
    if ($path eq 'cdna_checksum_path') {
      $checksum_hash = \%transcript_checksum;
    } else {
      $checksum_hash = \%peptide_checksum;
    }
    foreach my $line ( @{ slurp_to_array($self->param($path)) } ) {
      my ($id,$checksum) = split "\t",$line;
      $checksum_hash->{$id} = $checksum;
    };
  }
  throw('No Ensembl transcript checksums extracted from '.$self->param('cdna_checksum_path')) if (scalar(keys %transcript_checksum) == 0);
  throw('No Ensembl protein checksums extracted from '.$self->param('pep_checksum_path')) if (scalar(keys %peptide_checksum) == 0);
  $self->search_source_by_checksum('RefSeq',\%transcript_checksum,'ensembl_transcript',$run_id);
  $self->search_source_by_checksum('RNAcentral',\%transcript_checksum,'ensembl_transcript',$run_id);
  $self->search_source_by_checksum('Swissprot',\%peptide_checksum,'ensembl_protein',$run_id);
}


sub search_source_by_checksum {
  my ($self,$source,$checksum_hash,$type,$run_id) = @_;

  # Derive location of checksums
  my $indexer = Bio::EnsEMBL::Mongoose::IndexReader->new(species => $self->param('species'));

  my $path = $self->param('output_path');
  my $fh = IO::File->new($path.'/'.$source.'_checksum.ttl','w') or throw("Failed to open $path/${source}_checksum.ttl for writing");
  my $writer = Bio::EnsEMBL::Mongoose::Serializer::RDF->new(handle => $fh, config_file => $self->param('broker_conf'));
  $indexer->work_with_run(source => $source,run_id => $run_id);
  
  foreach my $ens_id (keys %$checksum_hash) {
    $indexer->query(
      Bio::EnsEMBL::Mongoose::Persistence::QueryParameters->new(
        output_format => 'RDF',
        checksum => $checksum_hash->{$ens_id},
        result_size => 1,
        species => $self->param('species')
      )
    ); 
    while (my $record = $indexer->next_record) {
      $writer->print_checksum_xrefs($ens_id,$type,$record,$source);
    }
  }
  $fh->close;

}


1;
