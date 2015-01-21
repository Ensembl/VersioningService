package Bio::EnsEMBL::Mongoose::Serializer::RDF;

use Moose;
use Bio::EnsEMBL::Mongoose::IOException;
extends 'Bio::EnsEMBL::Mongoose::Serializer::RDFLib';

sub print_record {
  my $self = shift;
  my $record = shift;
  my $source = shift;
  print "Record from $source\n";
  my $id = $record->id;
  unless ($id) {$id = $record->primary_accession}
  my $anchor = $self->identifiers($source).$id;
  
  # Attach description nodes to root
  my $annotation_bnode = $self->new_bnode;
  $self->triple($self->u($anchor),$self->u($self->prefix('dcterms').'source'), $annotation_bnode );
  $self->triple( $annotation_bnode, $self->u($self->prefix('rdf').'label'), $record->primary_accession );
  $self->triple( $annotation_bnode, $self->u($self->prefix('rdf').'type'), $self->u( $self->identifiers($source)) );

  foreach my $xref (@{$record->xref}) {
    next unless $xref->active == 1;
    print "Xref from ".$xref->source." ID: ".$xref->id."\n";
    my $source = $self->identifiers($xref->source);
    my $other = $source.$xref->id;
    my $bnode = $self->new_bnode;

    # entity comes from ...
    $self->triple($self->u($anchor),
                  $self->u($self->prefix('ensemblterm').'source'),
                  $self->u($self->prefix($source)) );
    # link to xref, note symmetric property to allow transitive queries, while preventing circular queries
    $self->triple($self->u($anchor),$self->u($self->prefix('ensemblterm').'refers-to'),$bnode);
    # xref links to target ID
    $self->triple($bnode,$self->u($self->prefix('ensemblterm').'refers-to'),$self->u($other));
    # reverse links
    unless ( $self->is_unidirectional(lc $xref->source)) {
      $self->triple($bnode,$self->u($self->prefix('ensemblterm').'refers-from'),$self->u($anchor));
      $self->triple($self->u($other),$self->u($self->prefix('ensemblterm').'refers-from'),$bnode);
    }
    # xref type
    $self->triple($bnode,$self->u($self->prefix('rdf').'type'),$self->u($self->prefix('ensemblterm').'Direct'));
    # if xref assertion came from a secondary/dependent source, mention them.
    if ($xref->creator) {
      $self->triple($bnode,$self->u($self->prefix('dcterms').'creator'),$self->u($self->identifier($xref->creator)));
    }
  }
}


__PACKAGE__->meta->make_immutable;

1;