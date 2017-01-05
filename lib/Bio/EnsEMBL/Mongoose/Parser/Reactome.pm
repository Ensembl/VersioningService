=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

=head1 NAME

Bio::EnsEMBL::Mongoose::Parser::Reactome - A class to parse Reactomes's Ensembl2Reactome_All_Levels.txt and UniProt2Reactome_All_Levels.txt files

=head1 DESCRIPTION

This is a class which is used to Parse the Reactome's Ensembl2Reactome_All_Levels.txt and UniProt2Reactome_All_Levels.txt files
As of writing, the source file is tab limited text file and has the following 6 columns

Column 1) Source database identifier, e.g. UniProt, ENSEMBL, NCBI Gene or ChEBI identifier
Column 2) Reactome Stable identifier
Column 3) URL
Column 4) Event (Pathway or Reaction) Name
Column 5) Evidence Code
Column 6) Species

For more info about the files, please refer: http://www.reactome.org/download/mapping.README.txt
=cut

package Bio::EnsEMBL::Mongoose::Parser::Reactome;
use Moose;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
with 'Bio::EnsEMBL::Mongoose::Parser::Parser', 'MooseX::Log::Log4perl';

# Requires access to compara taxonomy database, due to lack of taxon ID in miRBase files
use Bio::EnsEMBL::Mongoose::Taxonomizer;
use Try::Tiny;

has 'taxonomizer' => (
    isa => 'Bio::EnsEMBL::Mongoose::Taxonomizer',
    is => 'ro',
    lazy => 1,
    default => sub {
        return Bio::EnsEMBL::Mongoose::Taxonomizer->new;
    }
);


sub read_record {
  my $self = shift;
  $self->clear_record;
  my $record  = $self->record;
  my $fh      = $self->source_handle;
  my $content = <$fh>;
  return unless $content;

  chomp($content);
  my ($source_db_id, $reactome_id, $url, $description, $evidence, $species) = split /\t+/,$content;

  my $taxon_id = $self->taxonomizer->fetch_taxon_id_by_name($species);
  return unless ($taxon_id);
  
  my $source;
  if ($source_db_id =~ /^[OPQ][0-9][A-Z0-9]{3}[0-9]|[A-NR-Z][0-9]([A-Z][A-Z0-9]{2}[0-9]){1,2}$/) { #Uniprot accession regex Ref: http://www.uniprot.org/help/accession_numbers
    $source = 'Uniprot';
  }
  elsif ($source_db_id =~ /^ENS[GTP][0-9]*$/) { 
    $source = 'Ensembl';
  }
  else {
    # Does not match Uniprot or Ensembl stable id format
    return 0;
  }
  
  $record->id( $reactome_id );
  $record->primary_accession($reactome_id);
  $record->gene_name($source_db_id) if $source eq 'Ensembl';
  $record->display_label($reactome_id);
  $record->description($description);
  $record->taxon_id($taxon_id);
  
  $record->add_xref(Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => $source,creator => 'Reactome',id => $source_db_id));

  return 1;

}


__PACKAGE__->meta->make_immutable;