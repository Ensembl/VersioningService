package Bio::EnsEMBL::Mongoose::Parser::TextParser;
use Moose::Role;
use Moose::Util::TypeConstraints;

use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;

# Consumes HGNC file and emits Mongoose::Persistence::Records
with 'MooseX::Log::Log4perl';

# 'uni','http://uniprot.org/uniprot'
with 'Bio::EnsEMBL::Mongoose::Parser::Parser';

has content => (
    is => 'rw',
    isa => 'Str'
);

has header => (
    is => 'rw',
    isa => 'Str'
);

has delimiter => (
    is => 'ro',
    isa => 'Str',
    default => "\t",
    lazy => 1,
);

sub slurp_content {
    my $self = shift;
    my $handle = $self->source_handle;
    if (!$handle) { return; }
    my $content = <$handle>;
    if (!$content) { return; }

    unless ($self->header) {
        my $header = $self->check_header($content);
        $self->header($header);
        $content = <$handle>;
    }
    $self->{'current_block'} = [ split($self->delimiter, $content) ];
    $self->content($self->header.$content);
    return 1;
}

sub check_header {
  my $self = shift;
  my $content = shift;
  return $content;
}

1;
