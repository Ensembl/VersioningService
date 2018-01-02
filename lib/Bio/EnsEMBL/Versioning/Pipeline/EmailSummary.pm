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

package Bio::EnsEMBL::Versioning::Pipeline::EmailSummary;

use strict;
use warnings;
use parent qw/Bio::EnsEMBL::Hive::RunnableDB::NotifyByEmail/;
use Bio::EnsEMBL::Hive::Utils qw/destringify/;

sub fetch_input {
  my $self = shift;
  
  # Compose content
  my $msg = "Your Versioning Pipeline has finished. Results as follows:\n\n";
  
  for my $job_type (qw/ScheduleSources CheckLatest DownloadSource JobPerFile CollateIndexes/) {
    my $report = $self->jobs($job_type);
    $msg .= sprintf "Job type %s    Succeeded: %d    Failed: %d\n",$report->{name},$report->{successful_jobs},$report->{failed_jobs};
  }

  # Check for individual parsing job errors, as reported by accu
  my $parse_error_hashref = $self->param('error_bucket');
  if (defined $parse_error_hashref) {
    my %parse_errors = %{ $parse_error_hashref };
    foreach my $source (keys %parse_errors) {
      $msg .= "\n\n PARSING JOBS FAILED FOR $source. Index for source not updated\n";
      foreach my $err (@{ $parse_errors{$source} }) {
        $msg .= $err ."\n";
      }
    }
  }

  $self->param('text', $msg);
  return;
}

sub jobs {
  my ($self, $logic_name) = @_;
  my $aa = $self->db->get_AnalysisAdaptor();
  my $aja = $self->db->get_AnalysisJobAdaptor();
  my $analysis = $aa->fetch_by_logic_name($logic_name);
  my @jobs;
  if (!$analysis) {
    return {
      name => $logic_name,
      successful_jobs => 0,
      failed_jobs => 0,
      jobs => \@jobs,
    };
  }
  my $id = $analysis->dbID();
  @jobs = @{$aja->fetch_all_by_analysis_id_status([$analysis])};

  return {
    analysis => $analysis,
    name => $logic_name,
    jobs => \@jobs,
    successful_jobs => scalar(grep { $_->status eq 'DONE' } @jobs),
    failed_jobs => scalar(grep { $_->status eq 'FAILED' } @jobs),
  };
}

1;
