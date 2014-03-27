=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

sub run {
  my ($self) = @_;
  my $source_name = $self->param('source_name');
  my $specific_version = $self->param('version');
  my $broker = Bio::EnsEMBL::Versioning::Broker->new;

  my $source;
  if (defined $specific_version) {
    $source = $broker->get_source_by_name_and_version($source_name,$specific_version);
  } else {
    $source = $broker->get_current_source_by_name($source_name);
  }

  my $parser_name = $self->get_module($source->parser);
  my $files = $broker->get_file_list_for_source($source);
  my $temp = $broker->temp_location.'/'.$source_name.'.index';
  my $total_records = 0;
  my $doc_store;
  foreach (@$files) {
    my $parser = $parser_name->new(source_file => $_);
    
    $doc_store = $broker->document_store($temp);
    my $buffer = 0; 

    while($parser->read_record) {
      my $record = $parser->record;
      $doc_store->store_record($record);
      $buffer++;
      if ($buffer % 100000 == 0) {
          $doc_store->commit;
          $doc_store = $broker->document_store;
      }
    }
    $total_records += $buffer;
    $doc_store->commit;
  }
  $broker->finalise_index($source,$doc_store,$total_records);
}

1;