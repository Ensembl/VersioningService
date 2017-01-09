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

package Bio::EnsEMBL::Mongoose::Utils::BackgroundLauncher;

use Moose::Role;
use Proc::Background;
use Bio::EnsEMBL::Mongoose::IOException;
use Bio::EnsEMBL::Mongoose::UsageException;

has args => (
  isa => 'HashRef',
  is => 'rw',
);

has command => ( isa => 'Str', is => 'rw');

has process => (
  isa => 'Proc::Background',
  is => 'rw',
  clearer => 'stop_background_process'
);

sub run_command {
  my $self = shift;
  my @opts = $self->build_command_line;

  print "Debug: ".$self->command.' '.join(' ',@opts)."\n";
  
  my $proc = Proc::Background->new(
      {die_upon_destroy => 1},
      $self->command,
      @opts
  );
  unless ($proc->alive) {
    Bio::EnsEMBL::Mongoose::IOException->throw("Unable to launch sub-process ". $self->command.' '.join(' ',@opts)."\n");
  }
  $self->process($proc);
}

sub build_command_line {
  my $self = shift;
  unless ($self->command) { 
    Bio::EnsEMBL::Mongoose::UsageException->throw( "Cannot build a command line instruction without both a base command to run" );
  }
  my @opts = map { '--'.join '=',$_,$self->args->{$_} } keys $self->args;
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