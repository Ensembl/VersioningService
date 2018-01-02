=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Mongoose::Parser::TextParser;
use Moose::Role;
use Moose::Util::TypeConstraints;

use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;

# Consumes text file and emits
with 'MooseX::Log::Log4perl','Bio::EnsEMBL::Mongoose::Parser::Parser';

has content => (
    is => 'rw',
    isa => 'Str',
    default => ''
);

has header => (
    is => 'rw',
    isa => 'Str',
    clearer => 'empty_header'
);

has delimiter => (
    is => 'rw',
    isa => 'Str',
    default => "\n",

);

has peek_buffer => (
    is => 'rw',
    isa => 'Str',
    predicate => 'stuff_in_buffer',
    clearer => 'empty_buffer'
);

has current_line => (
    is => 'rw', isa => 'Str'
);

# peek buffer not implemented.

sub is_comment {
  my $self = shift;
  my $line = shift;
  return 1 if $line =~ /^#/;
  return;
}

sub slurp_it_all {
  my $self = shift;
  my $fh = $self->source_handle;
  my @content = ();
  while (my $line = <$fh>) {
    unless ($self->is_comment($line)) { push @content, $line }
  }
  return \@content;
}

1;
