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

package Bio::EnsEMBL::Mongoose::Parser::MIM2GeneMedGen;
use Modern::Perl;
use Moose;
use Moose::Util::TypeConstraints;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;
use Try::Tiny;
use Bio::EnsEMBL::Mongoose::IOException;
with 'Bio::EnsEMBL::Mongoose::Parser::TextParser','MooseX::Log::Log4perl';

# consumes the whole mim2gene_medgen file in one go so we can do look-ahead.
# see also primary parser consuming omim.txt file
# MIM provides two different datasets in one download; morbidities and gene data, but the difference is ignored in this source

has content_as_record => (
  traits => ['Array'],
  isa => 'ArrayRef[Bio::EnsEMBL::Mongoose::Persistence::Record]',
  is => 'rw',
  builder => '_digest_content',
  lazy => 1,
  handles => {
    has_records => 'count',
    one_record => 'pop'
  }
);

sub read_record {
  my $self = shift;
  return if ($self->has_records < 1 );
  $self->record($self->one_record);
  return $self->record;
}

sub _digest_content {
  my $self = shift;
  my @lines = @{ $self->slurp_it_all };
  chomp @lines;
  my %records;
  my @record_list;
  # Follow-up lines can refer to the same ID again
  foreach my $line (@lines) {
    my ($id,$entrezgene,$type,$source,$medgen,$comment) = split "\t",$line;
    push @{ $records{$id} },{ entrezgene => $entrezgene, type => $type, medgen => $medgen};
  }
  foreach my $id (keys %records) {
    my $record = Bio::EnsEMBL::Mongoose::Persistence::Record->new(id => $id, accessions => [$id], taxon_id => 9606);
    foreach my $xref (@{ $records{$id} }) {
      if (exists $xref->{medgen} and $xref->{medgen} ne '-') {
        $record->add_xref(Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => 'MedGen',creator => 'MIM',id => $xref->{medgen}));
      }
      if (exists $xref->{entrezgene} and $xref->{entrezgene} ne '-') {
        $record->add_xref(Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => 'EntrezGene',creator => 'MIM',id => $xref->{entrezgene}));
      }      
    }
    push @record_list,$record;
  }
  @record_list = sort {$b->id <=> $a->id} @record_list;
  return \@record_list;
}

1;
