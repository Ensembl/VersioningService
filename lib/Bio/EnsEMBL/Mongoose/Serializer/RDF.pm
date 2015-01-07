package Bio::EnsEMBL::Mongoose::Serializer::RDF;

use Moose;
use Bio::EnsEMBL::Mongoose::IOException;
extends 'Bio::EnsEMBL::Mongoose::Serializer::RDFLib';

sub print_record {
  my $self = shift;
  my $record = shift;
  my $source = shift;
  my $fh = $self->handle;
  print "Record from ".$source."\n";
  my $anchor = $self->prefix($source).$record->primary_accession;
  foreach my $xref (@{$record->xref}) {
    next unless $xref->active == 1;
    print "Xref from ".$xref->source." ID: ".$xref->id."\n";
    my $other = $self->prefix($xref->source).$xref->id;
    my $bnode = $self->new_bnode;
    print $fh $self->triple($self->u($anchor),
                     $self->prefix('ensemblterm')."source",
                     $self->u($self->prefix($source)))
      or Bio::EnsEMBL::Mongoose::IOException->throw(message => "Error writing to file handle: $!");
    print $fh $self->triple($self->u($anchor),$self->prefix('ensemblterm')."xref",$bnode);
    print $fh $self->triple($bnode,$self->prefix('ensemblterm')."refers-to",$self->u($other));
    print $fh $self->triple($bnode,$self->prefix('rdf')."type",$self->prefix('ensemblterm').'Direct');
    print $fh $self->triple($self->u($other),$self->prefix('ensemblterm')."source",$self->u($self->prefix($source)));
  }
}


__PACKAGE__->meta->make_immutable;

1;