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

  # Derive location of checksums
  my $indexer = Bio::EnsEMBL::Mongoose::IndexReader->new(species => $species);

  $self->param('indexer',$indexer);
  $self->param_required('cdna_path');
  $self->param_required('pep_path');
  
  # Define where the RDF output will go and create the folder
  my $output_path = File::Spec->join( $self->param('base_path'), 'xref', $self->param('run_id'), $species, "xref_rdf_dumps", 'checksum');
  if (!-d $output_path) {
    make_path $output_path or die "Failed to create path: $output_path";
  }
  $self->param('output_path',$output_path);
}

sub run {
  my ($self) = @_;

  my $run_id = $self->param('run_id'); # Comes from hive param stack
  my $output_hash;

  # invert loop as required in order to deal with sources versus types
  foreach my $type (qw/cdna pep/) {
    # put id->checksum pairs into a hash directly from file from DumpEnsemblFASTA
    my %ens_checksum = map { my ($id,$checksum) = split "\t"; ($checksum,$id); } @{ slurp_to_array($type.'_path')};
    my $source;
    if ($type eq 'cdna') {
      $source = 'RefSeq';
    } elsif ($type eq 'pep') {
      $source = 'UniprotSwissprot';
    }
    my $checksum_path = $self->search_source_by_checksum($source,\%ens_checksum,$run_id);
    $output_hash->{ species => $self->param('species'), source => $source, type => $type, checksum => $checksum_path};
    # store in checksum_ttl_path accumulator
    $self->dataflow_output_id($output_hash,2);
  }
}


sub search_source_by_checksum {
  my ($self,$source,$checksum_hash,$run_id) = @_;
  my $indexer = $self->param('indexer');
  my $path = $self->param('output_path');
  my $full_output_path = $path.$source.'_checksum.ttl';
  my $fh = IO::File->new($full_output_path,'w') or throw("Failed to open $full_output_path for writing");
  my $writer = Bio::EnsEMBL::Mongoose::Serializer::RDF->new(handle => $fh);
  $indexer->work_with_run($source,$run_id);
  
  my $ens_feature_type;
  if ($source eq 'RefSeq') {
    $ens_feature_type = 'transcript';
  } elsif ($source eq 'UniprotSwissprot') {
    $ens_feature_type = 'protein';
  }
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
      $writer->print_checksum_xrefs($ens_id,$ens_feature_type,$record,$source);
    }
  }
  $fh->close;
  return $full_output_path;
}


1;