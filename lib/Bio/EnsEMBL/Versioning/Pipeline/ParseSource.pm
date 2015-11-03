=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Versioning::Pipeline::ParseSource

=head1 DESCRIPTION

eHive pipeline module for the consumption of a downloaded resource into a document store

=cut

package Bio::EnsEMBL::Versioning::Pipeline::ParseSource;

use strict;
use warnings;

use Bio::EnsEMBL::Versioning::Broker;
use parent qw/Bio::EnsEMBL::Versioning::Pipeline::Base/;

use Try::Tiny;

sub run {
  my ($self) = @_;
  my $source_name = $self->param('source_name');
  my $specific_version = $self->param('version');
  my $broker = Bio::EnsEMBL::Versioning::Broker->new;

  my $version;
  if (defined $specific_version) {
    $version = $broker->get_version_of_source($source_name,$specific_version);
  } else {
    $version = $broker->get_current_version_of_source($source_name);
  }

  my $parser_name = $broker->get_module($broker->get_source($source_name)->parser);
  if ($parser_name eq 'Bio::EnsEMBL::Mongoose::Parser::RefSeq') {
    # Unpack files for uncooperative Refseq parser that doesn't take file handles.
    my $path = $version->uri;
    `gunzip $path/*.gz`;
  }
  my $files = $broker->get_file_list_for_version($version);
  my $temp = $broker->temp_location.'/'.$source_name.'.index';
  my $total_records = 0;
  my $doc_store;
  foreach (@$files) {
    my $parser = $parser_name->new(source_file => $_);
    
    $doc_store = $broker->document_store($temp);
    my $buffer = 0; 

    while($parser->read_record) {
      my $record = $parser->record;
      # validate record for key fields.
      if ($record->has_taxon_id && ($record->has_accessions || defined $record->id) {
        $doc_store->store_record($record);
        $buffer++;
      }
      if ($buffer % 100000 == 0) {
          $doc_store->commit;
          $doc_store = $broker->document_store($temp);
      }
    }
    $total_records += $buffer;
    $doc_store->commit;
  }
  if ($parser_name eq 'Bio::EnsEMBL::Mongoose::Parser::RefSeq') {
    # Repack files for Refseq parser to keep size down.
    my $path = $version->uri;
    `gzip $path/*`;
  }
  my $source = $broker->get_source($source_name);
  $broker->finalise_index($source,$specific_version,$doc_store,$total_records);
}

1;