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

Bio::EnsEMBL::Mongoose::Parser::DBASS - A class to parse a simple CSV file
downloaded from the DBASS web site.

=head1 DESCRIPTION

The columns of the file should be the following:

1) DBASS gene ID
2) DBASS gene name, can be in the form of primary_name/secondary_name or primary_name (secondary name)
3) Ensembl gene ID

=cut

package Bio::EnsEMBL::Mongoose::Parser::DBASS;

use Moose;

use Bio::EnsEMBL::Mongoose::IOException;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;

with 'Bio::EnsEMBL::Mongoose::Parser::Parser', 'MooseX::Log::Log4perl';

sub read_record {
  my $self = shift;
  $self->clear_record;
  my $record  = $self->record;
  $record->taxon_id(9606); # this is HUMAN 
  
  my $fh = $self->source_handle;
  my $content = <$fh>;
  return unless $content; # skip if empty record

  # if header advance to next record
  if ($content =~ /DBASS5GeneID/) {
    $content = <$fh>;
    return unless $content;
  }
  
  chomp($content);
  $content =~ s/\s*$//;
  $content =~ s/"//g; # csv format can come with quoted columns, remove them

  my ($dbass_gene_id, $dbass_gene_name, $ensembl_id) = split /,/, $content;
  Bio::EnsEMBL::Mongoose::IOException->throw ('Insufficient data in HPA line: ' . $content)
      unless $dbass_gene_id and $dbass_gene_name and $ensembl_id;
  Bio::EnsEMBL::Mongoose::IOException->throw ("Wrong Ensembl gene ID in DBASS line: $ensembl_id")
      if $ensembl_id !~ /^ENSG0{5}[0-9]{6}/;

  $record->id($dbass_gene_id);

  my $first_gene_name = $dbass_gene_name;
  my $second_gene_name;
  if ($dbass_gene_name =~ /.\/./) {
    ($first_gene_name, $second_gene_name) = split( /\//, $dbass_gene_name );
  }
	
  if ($dbass_gene_name =~ /(.*)\((.*)\)/) {
    $first_gene_name = $1;
    $second_gene_name = $2;
  }

  $first_gene_name =~ s/\s//g;
  $record->display_label($first_gene_name);
  if ($second_gene_name) {
    $second_gene_name =~ s/\s//g;
    $record->add_synonym($second_gene_name);
  }
  
  $record->add_xref(Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => 'Ensembl', creator => 'DBASS', id => $ensembl_id));

  return 1;
}

__PACKAGE__->meta->make_immutable;
