=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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
use JSON::SL;

with 'Bio::EnsEMBL::Mongoose::Parser::JSONParser','MooseX::Log::Log4perl';

sub _prepare_stream {
  my $stream = JSON::SL->new();
  $stream->set_jsonpointer( ["/^"] );
  return $stream;
}


# Consumes RNACentral file and emits Mongoose::Persistence::Records
sub read_record {
  my $self = shift;
  $self->clear_record;
  my $match = $self->get_data;
  return unless $match; # no match, end of file.
  my %doc = %{$match->{Value} };

  my $record = $self->record;
  $record->id( $doc{rnacentral_id} );
  my $sequence = $doc{sequence};
  $record->sequence( $sequence );
  $record->sequence_length(length($doc{sequence}));
  $record->display_label($doc{rnacentral_id});
  $record->description( $doc{description});
  $record->taxon_id( $doc{taxon_id});
  $record->checksum($doc{md5});

    return 1;
}


__PACKAGE__->meta->make_immutable;

1;
