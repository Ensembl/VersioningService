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
has gene_model_handle => ('is' => 'ro', isa => 'Ref', predicate => 'model_elsewhere'); # Specify this to put RefSeq Gene models in another place

sub print_record {
  my $self = shift;
  my $record = shift;
  my $source = shift;
  my $fh = $self->handle;
  my $id = $record->id;
  unless ($id) {$id = $record->primary_accession}
  my $clean_id = uri_escape($id);
  $source = uri_escape($source);
  my $namespace = $self->identifier($source);
  $namespace = $self->prefix('ensembl').$source.'/' unless $namespace;
  my $base_entity = $namespace.$clean_id;
  # Attach description and labels to root

  print $fh $self->triple($self->u($base_entity),$self->u($self->prefix('dcterms').'source'), $self->u( $self->identifier($source) ));
  print $fh $self->triple($self->u($base_entity),$self->u($self->prefix('dc').'identifier'), qq/"$id"/);
  if ($record->primary_accession) {
    print $fh $self->triple($self->u($base_entity), $self->u($self->prefix('rdfs').'label'), '"'.$record->primary_accession.'"' );
  }
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
  # For when a transcript-based-record references a protein from the same source. A bit fragile I suppose, but mainly only required for RefSeq data
  if ($record->protein_name) {
    $self->print_gene_model_link(undef,undef,$record->id,$source,$record->protein_name,$source);
  }
  # For when a RefSeq record references a gene, it is always referring to NCBIGene, aka EntrezGene
  if ($record->gene_name && $source =~ /refseq/i) {
    my $gene_source = 'EntrezGene';
    $self->print_gene_model_link($record->gene_name,$gene_source,$record->id,$source,undef,undef);
  }

  foreach my $xref (@{$record->xref}) {
    next unless $xref->active == 1;
    my $xref_source = $self->identifier(uri_escape($xref->source));
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
# This will be much more efficient to traverse in all directions so that we can find all the connected sets of URIs.
# Restricted by allowed_xrefs function to limit links to between objects of the same type, e.g. gene->gene, transcript->transcript
sub print_slimline_record {
  my $self = shift;
  my $record = shift;
  my $source = shift;
  my $fh = shift; # To bypass default filehandle
  $fh ||= $self->handle;
  # gratuitous copy paste from print_record()
  my $id = $record->id;
  unless ($id) {$id = $record->primary_accession}
  my $clean_id = uri_escape($id);
  # $source = uri_escape($source);
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
  my $ens_type = shift; # Basically transcript or peptide. Leave unset for gene
  my $record = shift; # record from index that contains the checksum we matched previously
  my $source = shift; # source of the thing the checksum matches to, namely refseq and a limited few others

  my $id = $record->id;
  unless ($id) {$id = $record->primary_accession}

  # Where a non-gene feature type, use a different prefix for the feature URI
  my $ens_namespace = 'ensembl';
  if ($ens_type ) {
    $ens_namespace = $ens_type;
  }
  
  my ($xref_source,$xref_link,$xref_target) = $self->generate_uris($ens_id,$ens_namespace,$id,$source,'checksum');
  
  my $fh = $self->handle;
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
  print $fh $self->triple($self->u($xref_source), $self->u($self->prefix('dcterms').'source'), $self->u($self->identifier($source)));
}

# Not useful for production. Checksums are not chosen by default.
sub print_slimline_checksum_xrefs {
  my $self = shift;
  my $ens_id = shift;
  my $ens_type = shift;
  my $record = shift;
  my $source = shift;

  my $ens_namespace = 'ensembl';
  if ($ens_type ) {
    $ens_namespace = $ens_type;
  }

  my $id = $record->id;
  unless ($id) {$id = $record->primary_accession}
  my $clean_id = uri_escape($id);
  my ($xref_source,undef,$xref_target) = $self->generate_uris($ens_id,$ens_namespace,$id,$source);
  
  my $fh = $self->handle;
  print $fh $self->triple($self->u($xref_source), $self->u($self->prefix('term').'refers-to'), $self->u($xref_target) );
  print $fh $self->triple($self->u($xref_target), $self->u($self->prefix('term').'refers-to'), $self->u($xref_source) );
  print $fh $self->triple($self->u($xref_target),$self->u($self->prefix('dc').'identifier'), qq/"$id"/);
  print $fh $self->triple($self->u($xref_source),$self->u($self->prefix('dc').'identifier'), qq/"$ens_id"/);
}

sub print_alignment_xrefs {
  my ($self,$source_id,$source,$target_id,$target_source,$score,$special_label) = @_;
  # use $special_label where necessary for parallel processes not being aware of each other
  my ($xref_source,$xref_link,$xref_target) = $self->generate_uris($source_id,$source,$target_id,$target_source,'align'.$special_label);
  
  my $fh = $self->handle;
  # Attach sources (redundantly) to all IDs to allow controlled subsets.
  print $fh $self->triple($self->u($xref_source),$self->u($self->prefix('dcterms').'source'), $self->u( $self->identifier($source) ));
  print $fh $self->triple($self->u($xref_target),$self->u($self->prefix('dcterms').'source'), $self->u( $self->identifier($target_source) ));
  # We may have trouble with labels on every single one, as they will aggregate in the graph (unlike URIs do), when merged with data from, e.g. overlap.
  # Then we get multiple hits for the same literal but yielding just one node.
  print $fh $self->triple($self->u($xref_source),$self->u($self->prefix('dc').'identifier'), qq/"$source_id"/);
  print $fh $self->triple($self->u($self->identifier($target_source)),$self->u($self->prefix('dc').'identifier'), qq/"$target_id"/);

  print $fh $self->triple($self->u($xref_source),$self->u($self->prefix('term').'refers-to'), $self->u($xref_link));
  print $fh $self->triple($self->u($xref_link),$self->u($self->prefix('term').'refers-to'), $self->u($xref_target));

  print $fh $self->triple($self->u($xref_link),$self->u($self->prefix('rdf').'type'),$self->u($self->prefix('term').'Alignment'));
  print $fh $self->triple($self->u($xref_link),$self->u($self->prefix('term').'score'),qq/"$score"/);
}


# Not useful at this time. The "slimline" graph is generated from queries, not directly from unfiltered alignments
sub print_slimline_alignment_xrefs {
  my ($self,$source_id,$source,$target_id,$target_source) = @_;

  my ($xref_source,undef,$xref_target) = $self->generate_uris($source_id,$source,$target_id,$target_source);

  my $fh = $self->handle;
  print $fh $self->triple($self->u($xref_source), $self->u($self->prefix('term').'refers-to'), $self->u($xref_target));
  print $fh $self->triple($self->u($xref_target), $self->u($self->prefix('term').'refers-to'), $self->u($xref_source));
  print $fh $self->triple($self->u($xref_source),$self->u($self->prefix('dc').'identifier'), qq/"$source_id"/);
  print $fh $self->triple($self->u($xref_target),$self->u($self->prefix('dc').'identifier'), qq/"$target_id"/);
}

# Generates a triad of URIs for a two-step Xref link, i.e. source_id refers-to xref refers-to target_id
# $label parameter allows additional disambiguation of the xref link, for data generated by different processes
sub generate_uris {
  my ($self,$source_id,$source,$target_id,$target_source,$label) = @_;

  my $start = $self->identifier($source).uri_escape($source_id);

  my $middle = $self->new_xref($source,$target_source,$label);

  my $end = $self->identifier($target_source).uri_escape($target_id);
  return ($start,$middle,$end);
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

  my ($xref_source,$xref_link,$xref_target) = $self->generate_uris($ens_id,'ensembl_transcript',$clean_id,$source,'overlap');

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

# Not useful at this time. The "slimline" graph is generated from queries, not directly from unfiltered alignments
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
  print $fh $self->triple($self->u($xref_target), $self->u($self->prefix('term').'refers-to'), $self->u($xref_source) );
  print $fh $self->triple($self->u($xref_source),$self->u($self->prefix('dc').'identifier'), qq/"$ens_id"/);
  print $fh $self->triple($self->u($xref_target),$self->u($self->prefix('dc').'identifier'), qq/"$id"/);
}

# Creates a gene->transcript->translation relation so that we can find the related transcript to a translation and so on
sub print_gene_model_link {
  my $self = shift;
  my $gene_id = shift;
  my $gene_source = shift;
  my $transcript_id = shift;
  my $transcript_source = shift;
  my $protein_id = shift;
  my $protein_source = shift;

  my $fh = $self->handle;
  if ($self->gene_model_handle) {
    $fh = $self->gene_model_handle;
  }
  my ($namespace,$gene_uri,$transcript_uri,$protein_uri);

  $namespace = $self->identifier($transcript_source);
  $transcript_uri = $namespace.$transcript_id;
  
  if ($gene_id) {
    $namespace = $self->identifier($gene_source);
    $gene_uri = $namespace.$gene_id;
    print $fh $self->triple($self->u($gene_uri), $self->u($self->prefix('obo').'SO_transcribed_to'), $self->u($transcript_uri));
    print $fh $self->triple($self->u($transcript_uri), $self->u($self->prefix('obo').'SO_transcribed_from'), $self->u($gene_uri));
  }

  if ($protein_id) {
    $namespace = $self->identifier($protein_source);
    $protein_uri = $namespace.$protein_id;
    print $fh $self->triple($self->u($transcript_uri), $self->u($self->prefix('obo').'SO_translates_to'), $self->u($protein_uri));
    print $fh $self->triple($self->u($protein_uri), $self->u($self->prefix('obo').'SO_translation_of'), $self->u($transcript_uri));
  }
}


__PACKAGE__->meta->make_immutable;

1;
