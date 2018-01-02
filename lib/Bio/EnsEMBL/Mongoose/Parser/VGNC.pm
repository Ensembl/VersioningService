=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Mongoose::Parser::VGNC - A class to parse a tab separated file
representing VGNC data for chimp.

=head1 DESCRIPTION

The parsed file contains the following entries:

0)  taxon_id
1)  vgnc_id 
2)  symbol
3)  name	
4)  locus_group	
5)  locus_type
6)  status
7)  location
8)  location_sortable:
9)  alias_symbol
10  alias_name
11) prev_symbol	
12) prev_name
13) gene_family
14) gene_family_id
15) date_approved_reserved
16) date_symbol_changed
17) date_name_changed
18) date_modified
19) entrez_id
20) ensembl_gene_id

=cut

package Bio::EnsEMBL::Mongoose::Parser::VGNC;

use Moose;

use Bio::EnsEMBL::Mongoose::IOException;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;

with 'Bio::EnsEMBL::Mongoose::Parser::Parser', 'MooseX::Log::Log4perl';

sub read_record {
  my $self = shift;
  $self->clear_record;
  my $record  = $self->record;
  
  my $fh = $self->source_handle;
  my $content = <$fh>;
  return unless $content; # skip if empty record

  # if header advance to next record
  if ($content =~ /^taxon_id/) {
    $content = <$fh>;
    return unless $content;
  }
  
  chomp($content);
  $content =~ s/\s*$//;
  my @fields = split /\t/, $content;
  my ($taxon_id, $vgnc_id, $symbol, $name, $alias_symbol, $prev_symbol, $ensembl_gene_id) = ($fields[0], $fields[1], $fields[2], $fields[3], $fields[9], $fields[11], $fields[20]);
  $record->taxon_id($taxon_id);
  
  Bio::EnsEMBL::Mongoose::IOException->throw ('Insufficient data in VGNC line: ' . $content)
      unless $taxon_id and $vgnc_id and $symbol and $name;

  $record->id($vgnc_id);
  $record->accessions([ $vgnc_id ]);
  $record->display_label($symbol);
  $record->entry_name($name);

  $prev_symbol =~ s/"//g if $prev_symbol;
  map { $record->add_synonym($_) if $_ } ($alias_symbol, $prev_symbol);
  
  $record->add_xref(Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => 'Ensembl', creator => 'VGNC', id => $ensembl_gene_id))
    if $ensembl_gene_id;

  return 1;
}

__PACKAGE__->meta->make_immutable;
