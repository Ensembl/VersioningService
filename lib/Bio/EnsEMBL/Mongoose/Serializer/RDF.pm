# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#      http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package Bio::EnsEMBL::Mongoose::Serializer::RDF;

use Moose;
use Bio::EnsEMBL::Mongoose::IOException;
extends 'Bio::EnsEMBL::Mongoose::Serializer::RDFLib';

has fh => ('is' => 'ro', required => 1, isa => 'Ref');

sub print_record {
  my $self = shift;
  my $record = shift;
  my $source = shift;
  my $fh = $self->fh;
  print "Record from $source\n";
  my $id = $record->id;
  unless ($id) {$id = $record->primary_accession}
  my $anchor = $self->identifiers($source).$id;
  
  # Attach description nodes to root
  my $annotation_bnode = $self->new_bnode();
  print $fh triple(u($anchor),u(prefix('dcterms').'source'), $annotation_bnode );
  print $fh triple( $annotation_bnode, u(prefix('rdf').'label'), $record->primary_accession );
  print $fh triple( $annotation_bnode, u(prefix('rdf').'type'), u( $self->identifiers($source)) );

  foreach my $xref (@{$record->xref}) {
    next unless $xref->active == 1;
    print "Xref from ".$xref->source." ID: ".$xref->id."\n";
    my $source = $self->identifiers($xref->source);
    my $other = $source.$xref->id;
    my $bnode = $self->new_bnode();

    # entity comes from ...
    print $fh triple(u($anchor), u(prefix('ensemblterm').'source'), u(prefix($source)) );
    # link to xref, note symmetric property to allow transitive queries, while preventing circular queries
    print $fh triple(u($anchor),u(prefix('ensemblterm').'refers-to'),$bnode);
    # xref links to target ID
    print $fh triple($bnode,u(prefix('ensemblterm').'refers-to'),u($other));
    # reverse links
    unless ( $self->is_unidirectional(lc $xref->source)) {
      print $fh triple($bnode,u(prefix('ensemblterm').'refers-from'),u($anchor));
      print $fh triple(u($other),u(prefix('ensemblterm').'refers-from'),$bnode);
    }
    # xref type
    print $fh triple($bnode,u(prefix('rdf').'type'),u(prefix('ensemblterm').'Direct'));
    # if xref assertion came from a secondary/dependent source, mention them.
    if ($xref->creator) {
      print $fh triple($bnode,u(prefix('dcterms').'creator'),u($self->identifier($xref->creator)));
    }
  }
}


__PACKAGE__->meta->make_immutable;

1;