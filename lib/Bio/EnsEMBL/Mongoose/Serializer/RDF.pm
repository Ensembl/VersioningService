package Bio::EnsEMBL::Mongoose::Serializer::RDF;

use Moose;
use Bio::EnsEMBL::Mongoose::IOException;
extends 'Bio::EnsEMBL::Mongoose::Serializer::RDFLib';

sub print_record {
  my $self = shift;
  my $record = shift;
  my $source = shift;
  my $fh = $self->handle;
  print "Record from $source\n";
  my $anchor = $self->identifiers($source).$record->primary_accession;
  
  # Attach description nodes
  my $annotation_bnode = $self->new_bnode;
  print $fh $self->triple($self->u($anchor),$self->u($self->prefix('dcterms').'source'), $annotation_bnode );
  print $fh $self->triple( $annotation_bnode, $self->u($self->prefix('rdf').'label'), $record->primary_accession );
  print $fh $self->triple( $annotation_bnode, $self->u($self->prefix('rdf').'type'), $self->u( $self->identifiers($source)) );

  foreach my $xref (@{$record->xref}) {
    next unless $xref->active == 1;
    print "Xref from ".$xref->source." ID: ".$xref->id."\n";
    my $other = $self->prefix($xref->source).$xref->id;
    my $bnode = $self->new_bnode;

    # entity comes from ...
    print $fh $self->triple($self->u($anchor),
                $self->u($self->prefix('ensemblterm').'source'),
                $self->u($self->prefix($source)) )
      or Bio::EnsEMBL::Mongoose::IOException->throw(message => "Error writing to file handle: $!");
    # link to xref, note symmetric property to allow transitive queries, while preventing circular queries
    print $fh $self->triple($self->u($anchor),$self->u($self->prefix('ensemblterm').'refers-to'),$bnode);
    # xref links to target ID
    print $fh $self->triple($bnode,$self->u($self->prefix('ensemblterm').'refers-to'),$self->u($other));
    # reverse links
    unless ( $self->unidirectional_sources->matches(lc $xref->source)) {
      print $fh $self->triple($bnode,$self->u($self->prefix('ensemblterm').'refers-from'),$self->u($anchor));
      print $fh $self->triple($self->u($other),$self->u($self->prefix('ensemblterm').'refers-from'),$bnode);
    }
    # xref type
    print $fh $self->triple($bnode,$self->u($self->prefix('rdf').'type'),$self->u($self->prefix('ensemblterm').'Direct'));
    # if xref assertion came from a secondary/dependent source, mention them.
    if ($xref->creator) {
      print $fh $self->triple($bnode,$self->u($self->prefix('dcterms').'creator'),$self->u($self->prefix('ensembl').$xref->creator));
    }
  }
}


__PACKAGE__->meta->make_immutable;

1;