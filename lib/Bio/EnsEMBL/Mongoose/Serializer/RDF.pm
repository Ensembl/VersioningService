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

has handle => ('is' => 'ro', required => 1, isa => 'Ref');

sub print_record {
  my $self = shift;
  my $record = shift;
  my $source = shift;
  my $fh = $self->handle;
  my $id = $record->id;
  unless ($id) {$id = $record->primary_accession}
  my $namespace = $self->identifier($source);
  $namespace = $self->prefix('ensembl').$source.'/' unless $namespace;
  my $base_entity = $namespace.$id;
  $base_entity = $self->clean_for_uri($base_entity);
  # Attach description and labels to root

  print $fh $self->triple($self->u($base_entity),$self->u($self->prefix('dcterms').'source'), $self->u( $self->identifier($source) ));
  print $fh $self->triple($self->u($base_entity),$self->u($self->prefix('dc').'identifier'), qq/"$id"/);
  print $fh $self->triple($self->u($base_entity), $self->u($self->prefix('rdfs').'label'), '"'.$record->primary_accession.'"' );
  foreach my $label (@{ $record->accessions }) { 
    print $fh $self->triple($self->u($base_entity),$self->u($self->prefix('skos').'altLabel'),qq/"$label"/);
  }
  if ($record->checksum) {
    print $fh $self->triple($self->u($base_entity),$self->u($self->prefix('term').'checksum'),'"'.$record->checksum.'"');
  }
  if ($record->display_label) {
    print $fh $self->triple($self->u($base_entity),$self->u($self->prefix('term').'display_label'),'"'.$record->display_label.'"');
  }
  if ($record->description) {
    print $fh $self->triple($self->u($base_entity),$self->u($self->prefix('dc').'description'),'"'.$record->description.'"');
  }

  foreach my $xref (@{$record->xref}) {
    next unless $xref->active == 1;
    my $xref_source = $self->identifier($xref->source);
    my $xref_uri = $xref_source.$xref->id;
    $xref_uri = $self->clean_for_uri($xref_uri);
    $xref_source = $self->clean_for_uri($xref_source);
    my $xref_link = $self->new_xref;

    # xref is from data source... but not necessarily asserted by them. See creator below.
    # Root entity source uses different namespaced source than xref source to prevent confusion between directly asserted sources and 
    # inferred sources from a data providers' xrefs
    print $fh $self->triple($self->u($xref_uri), $self->u($self->prefix('dcterms').'source'), $self->u($xref_source));
    # Not all xrefs will get full information from their own source, so we put in what we think is the canonical identifier for the entity
    print $fh $self->triple($self->u($xref_uri), $self->u($self->prefix('dc').'identifier'), '"'.$xref->id.'"');
    # link to xref, 
    print $fh $self->triple($self->u($base_entity), $self->u($self->prefix('term').'refers-to'), $self->u($xref_link));
    # xref links to target ID
    print $fh $self->triple($self->u($xref_link), $self->u($self->prefix('term').'refers-to'), $self->u($xref_uri));
    # reverse links
    # Enable if it proves difficult to query in the reverse direction to complete the network.
    # unless ( $self->is_unidirectional(lc $xref->source)) {
    #   print $fh $self->triple($self->u($xref_link),$self->u($self->prefix('term').'refers-from'),$self->u($base_entity));
    #   print $fh $self->triple($self->u($xref_uri),$self->u($self->prefix('term').'refers-from'),$self->u($xref_link));
    # }
    # xref type
    print $fh $self->triple($self->u($xref_link),$self->u($self->prefix('rdf').'type'),$self->u($self->prefix('term').'Direct'));
    # if xref assertion came from a secondary/dependent source, mention them.
    if ($xref->creator) {
      print $fh $self->triple($self->u($xref_link),$self->u($self->prefix('dcterms').'creator'),$self->u($self->identifier($xref->creator)));
    }
  }
}


__PACKAGE__->meta->make_immutable;

1;