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

package Bio::EnsEMBL::Mongoose::Serializer::RDF;

use Moose;
use Bio::EnsEMBL::Mongoose::IOException;
use URI::Escape;
extends 'Bio::EnsEMBL::Mongoose::Serializer::RDFLib';

has handle => ('is' => 'ro', required => 1, isa => 'Ref');

sub print_record {
  my $self = shift;
  my $record = shift;
  my $source = shift;
  my $fh = $self->handle;
  my $id = $record->id;
  unless ($id) {$id = $record->primary_accession}
  my $clean_id = uri_escape($id);
  my $namespace = $self->identifier($source);
  $namespace = $self->prefix('ensembl').$source.'/' unless $namespace;
  my $base_entity = $namespace.$clean_id;
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
    print $fh $self->triple($self->u($base_entity),$self->u($self->prefix('dc').'description'),'"'.$self->escape($record->description).'"');
  }
  if ($record->comment) {
    print $fh $self->triple($self->u($base_entity),$self->u($self->prefix('rdfs').'comment'),'"'.$self->escape($record->comment).'"');
  }

  foreach my $xref (@{$record->xref}) {
    next unless $xref->active == 1;
    my $xref_source = $self->identifier($xref->source);
    my $clean_id = uri_escape($xref->id);
    my $xref_uri = $xref_source.$clean_id;
    my $xref_link = $self->new_xref($source,$xref->source);

    # xref is from data source... but not necessarily asserted by them. See creator below.
    # Root entity source uses different namespaced source than xref source to prevent confusion between directly asserted sources and 
    # inferred sources from a data providers' xrefs. e.g. A reactome link from Uniprot should not be namespaced from Uniprot.
    print $fh $self->triple($self->u($xref_uri), $self->u($self->prefix('dcterms').'source'), $self->u($xref_source));
    # Not all xrefs will get full information from their own source, so we put in what we think is the canonical identifier for the entity
    print $fh $self->triple($self->u($xref_uri), $self->u($self->prefix('dc').'identifier'), '"'.$xref->id.'"');
    # link to xref, 
    print $fh $self->triple($self->u($base_entity), $self->u($self->prefix('term').'refers-to'), $self->u($xref_link));
    # xref links to target ID
    print $fh $self->triple($self->u($xref_link), $self->u($self->prefix('term').'refers-to'), $self->u($xref_uri));
    # reverse links
    # Enable if it proves necessary to have reverse links for sources
    # if ( $self->identifier_mapping->is_bidirectional($xref->source)) {
    #   print $fh $self->triple($self->u($xref_link),$self->u($self->prefix('term').'refers-from'),$self->u($base_entity));
    #   print $fh $self->triple($self->u($xref_uri),$self->u($self->prefix('term').'refers-from'),$self->u($xref_link));
    # }
    # xref type
    print $fh $self->triple($self->u($xref_link),$self->u($self->prefix('rdf').'type'),$self->u($self->prefix('term').'Direct'));
    # Scope here to describe evidence codes and such (associated xrefs indeed) to qualify the xref itself.
    # if xref assertion came from a secondary/dependent source, mention that the link was created by the source of this record.
    # if ($xref->creator) {
    #   print $fh $self->triple($self->u($xref_link),$self->u($self->prefix('dcterms').'creator'),$self->u($self->identifier($xref->creator)));
    # }
  }
}

# Create a transitive network of simple xrefs and resources. No annotated middle node, just URIs, labels and sources.
# This will be much more efficient to traverse in all directions so that we can find the entire set of interlinked URIs
sub print_slimline_record {
  my $self = shift;
  my $record = shift;
  my $source = shift;
  # gratuitous copy paste from print_record()
  my $fh = $self->handle;
  my $id = $record->id;
  unless ($id) {$id = $record->primary_accession}
  my $clean_id = uri_escape($id);

  my $namespace = $self->identifier($source);
  $namespace = $self->prefix('ensembl').$source.'/' unless $namespace;
  my $base_entity = $namespace.$clean_id;
  
  # Label annotations for finding best IDs in a given scenario
  print $fh $self->triple($self->u($base_entity),$self->u($self->prefix('dc').'identifier'), qq/"$id"/);
  print $fh $self->triple($self->u($base_entity),$self->u($self->prefix('dcterms').'source'), $self->u( $self->identifier($source) ));
  
  foreach my $xref (@{$record->xref}) {
    next unless $xref->active == 1;
    my $xref_source = $self->identifier($xref->source);
    my $clean_id = uri_escape($xref->id);
    my $xref_uri = $xref_source.$clean_id;
    my $allowed = $self->identifier_mapping->allowed_xrefs($source,$xref->source);
    if ($allowed) {
      print $fh $self->triple($self->u($base_entity), $self->u($self->prefix('term').'refers-to'), $self->u($xref_uri));
      print $fh $self->triple($self->u($xref_uri), $self->u($self->prefix('term').'refers-to'), $self->u($base_entity));
      print $fh $self->triple($self->u($xref_uri),$self->u($self->prefix('dcterms').'source'), $self->u( $xref_source ));
    }
  }
}

sub print_checksum_xrefs {
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
  my $xref_link = $self->new_xref('ensembl',$source);

  $namespace = $self->identifier($source);
  $namespace = $self->prefix('ensembl').$source.'/' unless $namespace;
  my $xref_target = $namespace.$clean_id;
  # Meta about Ensembl ID
  print $fh $self->triple($self->u($xref_source), $self->u($self->prefix('dcterms').'source'), $self->u($self->prefix('ensembl')));
  print $fh $self->triple($self->u($xref_source),$self->u($self->prefix('dc').'identifier'), qq/"$ens_id"/);
  print $fh $self->triple($self->u($xref_source), $self->u($self->prefix('rdfs').'label'), qq/"$ens_id"/ );
  # Create link
  print $fh $self->triple($self->u($xref_source), $self->u($self->prefix('term').'refers-to'), $self->u($xref_link));
  print $fh $self->triple($self->u($xref_link), $self->u($self->prefix('term').'refers-to'), $self->u($xref_target));
  # Annotate link
  print $fh $self->triple($self->u($xref_link),$self->u($self->prefix('rdf').'type'),$self->u($self->prefix('term').'Checksum'));
  print $fh $self->triple($self->u($xref_target),$self->u($self->prefix('dc').'identifier'), qq/"$id"/);
}

sub print_slimline_checksum_xrefs {
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
      $self->u($mappings->{$source}), $self->u($self->prefix('rdfs').'label'), qq/"$source"/
    );
    my $full_map = $self->identifier_mapping->get_mapping($source);
    if (exists $full_map->{priority}) {
      print $fh $self->triple(
        $self->u($mappings->{$source}), $self->u($self->prefix('term').'priority'), $full_map->{priority}
      );
    }
  }
}

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

__PACKAGE__->meta->make_immutable;

1;
