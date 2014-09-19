package Bio::EnsEMBL::Mongoose::Serializer::RDF;

use Moose;
use Bio::EnsEMBL::Mongoose::IOException;

extends 'Bio::EnsEMBL::Mongoose::Serializer::RDFLib';

sub print_record {
  my $self = shift;
  my $record = shift;
  my $fh = $self->handle;
  my $anchor = prefix($self->source).$record->id;
  foreach my $xref (@{$record->xref}) {
    next unless $xref->active == 1;
    my $other = prefix($xref->source).$xref->id;
    my $bnode = $self->new_bnode;
    print $fh triple(u($anchor),prefix('ensemblterm')."source",u(prefix($self->source)))
      or Bio::EnsEMBL::Mongoose::IOException->throw(message => "Error writing to file handle: $!");
    print $fh triple(u($anchor),prefix('ensemblterm')."xref",$bnode);
    print $fh triple($bnode,prefix('ensemblterm')."refers-to",u($other));
    print $fh triple($bnode,prefix('rdf')."type",prefix('ensemblterm').'Direct');
    print $fh triple(u($other),prefix('ensemblterm')."source",u(prefix($xref->source)));
  }
}

1;