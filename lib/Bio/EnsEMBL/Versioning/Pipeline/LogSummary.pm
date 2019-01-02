=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

=pod


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Versioning::Pipeline::LogSummary

=head1 DESCRIPTION

eHive pipeline module to log the start and end time of the Xref pipeline run and
to store the versions/sources used in the pipeline run

=cut

package Bio::EnsEMBL::Versioning::Pipeline::LogSummary;

use strict;
use warnings;
use Bio::EnsEMBL::Versioning::Logger;
use Try::Tiny;
use Log::Log4perl;
Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

use parent qw/Bio::EnsEMBL::Versioning::Pipeline::Base/;

sub run {
  my ($self) = @_;
  my $begin_run = $self->param('begin_run');
  my $end_run = $self->param('end_run');
  my $run_id = $self->param('run_id');
  
  print "Runid: $run_id  Species ", $self->param('species'), "\n";
  
  my $logger = Bio::EnsEMBL::Versioning::Logger->new;
  my $message = {run_id => $run_id };
  
  if($run_id){
    if($begin_run && $end_run){
      ($run_id) = $logger->log_run(begin_run=>$begin_run, end_run=>$end_run, run_id=>$run_id);
    }
  	
  }else{
    ($run_id) = $logger->log_run(begin_run=>$begin_run, end_run=>$end_run);
    $message = { run_id => $run_id };
    $self->dataflow_output_id($message,2);
  }
  
  return;

}


1;
