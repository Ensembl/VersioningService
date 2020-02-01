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

# Simple wrapper for launching aligners through the shell and processing the output

package Bio::EnsEMBL::Mongoose::Utils::Aligner;

use Moose;
use Config::General;
use Moose::Util::TypeConstraints;
use Bio::EnsEMBL::Mongoose::IOException;

has exe => (is =>'rw',isa => 'Str');
has conf => (is => 'rw',isa => 'HashRef');
has source => (is => 'rw', isa => 'Str', required => 1); # source file containing reference sequence
has target => (is => 'rw', isa => 'Str', required => 1); # target file pattern for sequences to compare against
has user_parameters => (is => 'rw', isa => 'Str', default => ""); # one-time parameters not in the default set

sub output_filter {
  ...
}

# executes command with args, then returns whatever processed output seems relevant
sub run {
  my ($self) = @_;

  my $command_string = $self->build_command();
  $command_string .= $self->user_parameters if $self->user_parameters;
  my $output = `$command_string`;
  my $alignment = $self->output_filter($output);
  if ($output && $alignment && length($alignment) == 0 ) { 
    Bio::EnsEMBL::Mongoose::IOException->throw(sprintf "Error while running alignment. %s was executed, but output contained no alignments that filter could identify.\n %s\n",$self->exe, $command_string);
  }
  return $alignment;
}

sub build_command {
  ...
}

1;
