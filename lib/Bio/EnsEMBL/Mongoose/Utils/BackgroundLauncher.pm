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

package Bio::EnsEMBL::Mongoose::Utils::BackgroundLauncher;

use Moose::Role;
use Proc::Background;
use Bio::EnsEMBL::Mongoose::IOException;
use Bio::EnsEMBL::Mongoose::UsageException;

# key-value pairs of --option => $value, or --option
has args => (
  isa => 'HashRef',
  is => 'rw',
  default => sub{{}}
);

# for arguments that do not conform to --option=value or --option
has tail_end => (
  isa => 'Str',
  is => 'rw'
);

# the binary name to pass to the shell
has command => ( isa => 'Str', is => 'rw');

has process => (
  isa => 'Proc::Background',
  is => 'rw',
  clearer => 'stop_background_process'
);

has keepalive => ( isa => 'Bool', is => 'rw', default => 0); # should the server shut down again when the process quits?

sub run_command {
  my $self = shift;
  unless ($self->command) { 
    Bio::EnsEMBL::Mongoose::UsageException->throw( "Cannot build a command line instruction without a base command to run" );
  }
  my @opts = $self->unpack_args;
  push @opts,split /\s/,$self->tail_end if $self->tail_end;

  # use Data::Dumper;
  # print Dumper \@opts;
  my $proc_ops = {};
  $proc_ops = {die_upon_destroy => 1} unless $self->keepalive();
  my $proc = Proc::Background->new(
      $proc_ops,
      $self->command,
      @opts
  );
  unless ($proc && $proc->alive) {
    Bio::EnsEMBL::Mongoose::IOException->throw("Unable to launch sub-process ". $self->command.' '.join(' ',@opts)."\n");
  }
  $self->process($proc);
}

sub unpack_args {
  my $self = shift;
  my $args = $self->args;
  my $opt_string;
  my @opts;
  # Note that perl system() calls cannot combine arg names and values in a single string, so we keep them apart
  foreach my $arg (keys %$args) {
    push @opts,$arg;
    push @opts,$args->{$arg} if defined $args->{$arg};
  }
  return @opts;
}

sub get_pid {
  my $self = shift;
  return $self->process->pid;
}

sub background_process_alive {
  my $self = shift;
  return $self->process->alive if $self->process;
  return 0;
}

1;
