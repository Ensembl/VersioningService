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

package Bio::EnsEMBL::Versioning::Logger;

use Moose;
extends qw/Bio::EnsEMBL::Versioning::Broker/;

sub log_run{
  my $self = shift;
  my %args = @_;

  my $begin_run =  $args{begin_run};
  my $end_run =  $args{end_run};
  my $run_id = $args{run_id};
  my $version_id;
  
  if($begin_run && $end_run){
    #job has finished if end_run is 1. update run with end time
    $self->schema->resultset('Run')->find( $run_id )->update({end => DateTime->now() });
  }elsif($begin_run){
    #log the start time ...default is CURRENT_TIMESTAMP
    my $run = $self->schema->resultset('Run')->create({});
    $run_id = $run->run_id;
    
    #populate the version_run table with version_id and run_id for all active sources
    my $version;
    foreach my $source(@{$self->get_active_sources}){
      $version = $self->get_current_version_of_source($source->name);
      if (!$version) {
        $self->warning('No active version of source '.$source->name.'. Forced to ignore');
        next;
      }
      $self->schema->resultset('VersionRun')->create({version_id=>$version->version_id, run_id=>$run_id});
    }

    return ($run_id);
  }

  return ($run_id);
}


__PACKAGE__->meta->make_immutable;

1;
