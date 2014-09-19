# Superclass of things that get data from specific source indexes and turn them into triples.

package Bio::EnsEMBL::Mongoose::Serializer::RDFLib;

use Moose;

has namespace => (
  traits => ['Hash'],
  is => 'ro',
  isa => 'HashRef',
  default => sub { {
    ensembl => 'http://rdf.ebi.ac.uk/resource/ensembl/',
    ensemblterms => 'http://rdf.ebi.ac.uk/terms/ensembl/',
    rdf => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
    rdfs => 'http://www.w3.org/2000/01/rdf-schema#',
    rdfg => 'http://www.w3.org/2004/03/trix/rdfg-1/',
    # RDF graph descriptions.. subgraph etc.
    owl => 'http://www.w3.org/2002/07/owl#',
    dcterms => 'http://purl.org/dc/terms/identifier',
    obo => 'http://purl.obolibrary.org/obo/',
    # obo includes sequence ontology for some reason
    sio => 'http://semanticscience.org/resource/',
    faldo => 'http://biohackathon.org/resource/faldo',
  } },
  handles => { prefix => 'get'}
);

has bnode => ( is => 'rw', isa => 'Int', default => 0, handles => {bplus => 'inc'});

sub triple {
  my $self = shift;
  my ($subject,$predicate,$object) = @_;
  return sprintf "%s %s %s .\n",$subject,$predicate,$object;
}

sub u {
  my $stuff= shift;
  return '<'.$stuff.'>';
}

sub new_bnode {
  my $self = shift;
  $self->bplus;
  return '_'.$self->bnode;
}

sub dump_prefixes {
  my $self = shift;
  my $fh = $self->handle;
  my %namespaces = %{$self->namespace};
  foreach my $key (keys %namespaces) {
    print $fh triple('@prefix',$key.':',u($namespaces{$key}) );
  }
}


1;