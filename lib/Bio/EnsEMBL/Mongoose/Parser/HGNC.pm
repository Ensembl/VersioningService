package Bio::EnsEMBL::Mongoose::Parser::HGNC;
use Moose;
use Moose::Util::TypeConstraints;
use Bio::EnsEMBL::Mongoose::IOException qw(throw);

use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;

use JSON::SL; # streaming! woo!

has json_document => (
  is => 'rw',
  isa => 'JSON::SL',
  builder => '_prepare_stream',

);

# buffer of complete json fragments
has buffer => (
  traits => ['Array'],
  is => 'rw',
  isa => 'ArrayRef[HashRef]',
  default => sub {[]},
  handles => { add_record => 'push', next_record => 'shift'},
  predicate => 'content_available'
);

with 'Bio::EnsEMBL::Mongoose::Parser::Parser','MooseX::Log::Log4perl';

sub _prepare_stream {
  my $stream = JSON::SL->new();
  # Google JSON path
  $stream->set_jsonpointer( ["/response/docs/^"]);
  return $stream;
}

sub get_data {
  my $self = shift;
  my $fh = $self->source_handle;
  my $record = $self->next_record;
  # Slurping by bytes, the JSON parser fishes out sections that match the pattern above.
  # These are buffered here, so no slurping occurs until we have run out of parsed JSON
  # elements. It's not fast, but should keep memory consumption down.
  until (defined $record && exists $record->{Value}) {
    local $/ = \1024;
    my $fragment = <$fh>;
    return unless $fragment;
    my @matches = $self->json_document->feed($fragment);
    $self->add_record(@matches) if ($#matches > 0);
    $record = $self->next_record;
  }
  return $record;
}

# Consumes HGNC file and emits Mongoose::Persistence::Records
sub read_record {
    my $self = shift;
    $self->clear_record;
    my $match = $self->get_data;
    return unless $match; # no match, end of file.
    my %doc = %{$match->{Value} };
    $self->record->id($doc{hgnc_id});
    $self->record->accessions([$doc{hgnc_id}]) if exists $doc{hgnc_id};
    $self->record->display_label($doc{symbol}) if exists $doc{symbol};
    $self->record->gene_name($doc{name}) if exists $doc{name};
    my $list = $doc{prev_symbol} if exists $doc{prev_symbol};
    push @$list,@{$doc{alias_symbol}} if exists $doc{alias_symbol};
    foreach (@$list) {
      $self->add_synonym($_);
    }
    $self->create_xref('RefSeq',$doc{refseq_accession}) if exists $doc{refseq_accession};
    $self->create_xref('Ensembl',$doc{ensembl_gene_id}) if exists $doc{ensembl_gene_id};
    $self->create_xref('CCDS',$doc{ccds_id}) if exists $doc{ccds_id};
    if (exists $doc{lsdb} && $doc{lsdb} ~~ /LRG/) {
      $self->create_xref('LRG',$doc{lsdb});
    }
    return 1;
}


sub create_xref {
  my $self = shift;
  my $source = shift;
  my $id = shift;
  my @ids = ($id);
  if (ref $id eq 'ARRAY') {
    @ids = @$id;
  }
  foreach $id (@ids) {
    $self->record->add_xref(Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => $source, id => $id, creator => 'HGNC'));
  }
}

__PACKAGE__->meta->make_immutable;

1;