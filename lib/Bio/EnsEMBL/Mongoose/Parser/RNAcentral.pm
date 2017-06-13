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

package Bio::EnsEMBL::Mongoose::Parser::RNAcentral;
use Moose;
use Moose::Util::TypeConstraints;
use Bio::EnsEMBL::Mongoose::IOException qw(throw);

use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;
use Digest::MD5;


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
  $stream->set_jsonpointer( ["/^"] );
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
    $self->add_record(@matches) if (scalar(@matches) > 0);
    $record = $self->next_record;
  }
  return $record;
}

# Consumes RNACentral file and emits Mongoose::Persistence::Records
sub read_record {
    my $self = shift;
    $self->clear_record;
    my $match = $self->get_data;
    return unless $match; # no match, end of file.
    my %doc = %{$match->{Value} };

    my $record = $self->record;
    $record->id( $doc{"rnacentral_id"} );
    my $sequence = $doc{"sequence"};
    $record->sequence( $sequence );
    $record->sequence_length(length($doc{"sequence"}));
    $record->display_label($doc{"rnacentral_id"});
    $record->description( $doc{"description"});
    $record->taxon_id( $doc{"taxon_id"});

    my $md5 = $doc{"md5"};
    my $stomach = Digest::MD5->new;
    $stomach->add($sequence);
    my $checksum = $stomach->hexdigest;

    if ($md5 eq $checksum){
      $record->checksum($md5);
    } else {
      $self->log->warn("source md5 ($md5) and calculated checksum ($checksum) are not equal");
    }

    return 1;
}


__PACKAGE__->meta->make_immutable;

1;
