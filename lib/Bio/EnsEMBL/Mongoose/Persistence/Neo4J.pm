package Neo4J;

# In anticipation of Neo4J being an unfolding catastrophy, this module is ready to be abstracted for alternative backends...

use Moose;
use REST::Neo4p;
use REST::Neo4p::Batch;



with 'Bio::EnsEMBL::Mongoose::Persistence::DocumentStore';

sub init {
  my $self = shift;
  my %conf = %{ $self->config };
  my $connection_string = sprintf 'http://%s:%s',$conf{host},$conf{port};
  REST::Neo4p->connect($connection_string);
}

sub import_ids {
  my ($self,$list_of_ids) = @_;

  batch {
    while (my $id = shift @$list_of_ids) {
      REST::Neo4p::Node->new({ id => $id});
    }
  } 'discard_objs';
}

1;