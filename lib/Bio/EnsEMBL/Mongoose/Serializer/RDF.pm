package Bio::EnsEMBL::Mongoose::Serializer::RDF;

use Moose;
use Bio::EnsEMBL::Mongoose::IOException;

extends 'Bio::EnsEMBL::Mongoose::Serializer::RDFLib';

sub print_record {
  my $self = shift;
  my $record = shift;
  my $source = shift;
  my $fh = $self->handle;
  my $anchor = $self->prefix($source).$record->id;
  foreach my $xref (@{$record->xref}) {
    next unless $xref->active == 1;
    my $other = $self->prefix($xref->source).$xref->id;
    my $bnode = $self->new_bnode;
    print $fh triple(u($anchor),$self->prefix('ensemblterm')."source",u($self->prefix($source)))
      or Bio::EnsEMBL::Mongoose::IOException->throw(message => "Error writing to file handle: $!");
    print $fh triple(u($anchor),$self->prefix('ensemblterm')."xref",$bnode);
    print $fh triple($bnode,$self->prefix('ensemblterm')."refers-to",u($other));
    print $fh triple($bnode,$self->prefix('rdf')."type",$self->prefix('ensemblterm').'Direct');
    print $fh triple(u($other),$self->prefix('ensemblterm')."source",u($self->prefix($source)));
  }
}

1;