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

package Bio::EnsEMBL::Mongoose::Serializer::RDFCoordinateOverlap;

use Moose;
use Bio::EnsEMBL::Mongoose::IOException;
use URI::Escape;
extends 'Bio::EnsEMBL::Mongoose::Serializer::RDFLib';

has handle => ('is' => 'ro', required => 1, isa => 'Ref');


sub print_coordinate_overlap_xrefs {
  my $self = shift;
  my $ens_id = shift;
  my $record = shift;
  my $source = shift;
  my $score = shift;

  my $fh = $self->handle;
  my $id = $record->id;
  unless ($id) {$id = $record->primary_accession}
  my $clean_id = uri_escape($id);
  my $namespace = $self->identifier($source);

  my $xref_source = $self->prefix('ensembl').$ens_id;
  my $xref_link = $self->new_xref('ensembl',$source);

  $namespace = $self->identifier($source);
  $namespace = $self->prefix('ensembl').$source.'/' unless $namespace;
  my $xref_target = $namespace.$clean_id;
  # Meta about Ensembl ID
  print $fh $self->triple($self->u($xref_source), $self->u($self->prefix('dcterms').'source'), $self->u($self->prefix('ensembl')));
  print $fh $self->triple($self->u($xref_source),$self->u($self->prefix('dc').'identifier'), qq/"$ens_id"/);
  print $fh $self->triple($self->u($xref_source), $self->u($self->prefix('rdfs').'label'), '"'.$ens_id.'"' );
  # Create link
  print $fh $self->triple($self->u($xref_source), $self->u($self->prefix('term').'refers-to'), $self->u($xref_link));
  print $fh $self->triple($self->u($xref_link), $self->u($self->prefix('term').'refers-to'), $self->u($xref_target));
  # Annotate link
  print $fh $self->triple($self->u($xref_link),$self->u($self->prefix('rdf').'type'),$self->u($self->prefix('term').'Coordinate_overlap'));
  print $fh $self->triple($self->u($xref_target),$self->u($self->prefix('dc').'identifier'), qq/"$id"/);
  print $fh $self->triple($self->u($xref_link),$self->u($self->prefix('term').'score'),qq/"$score"/);
}

sub print_slimline_coordinate_overlap_xrefs {
  my $self = shift;
  my $ens_id = shift;
  my $record = shift;
  my $source = shift;

  my $fh = $self->handle;
  my $id = $record->id;
  unless ($id) {$id = $record->primary_accession}
  my $clean_id = uri_escape($id);
  my $namespace = $self->identifier($source);

  my $xref_source = $self->prefix('ensembl').$ens_id;
  my $xref_link;

  $namespace = $self->identifier($source);
  $namespace = $self->prefix('ensembl').$source.'/' unless $namespace;
  my $xref_target = $namespace.$clean_id;

  print $fh $self->triple($self->u($xref_source), $self->u($self->prefix('term').'refers-to'), $self->u($xref_target) );
}


# Write triples which attach source labels to sources, handy for pretty printing or maybe text search
sub print_source_meta {
  my $self = shift;
  my $fh = $self->handle;
  my $mappings = $self->identifier_mapping->get_all_name_mapping;
  foreach my $source (keys %$mappings) {
    print $fh $self->triple( 
      $self->u($mappings->{$source}), $self->u($self->prefix('rdfs').'label'), '"'.$source.'"'
    );
  }
}


__PACKAGE__->meta->make_immutable;

1;

