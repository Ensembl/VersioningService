=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Pipeline::EmailSummary;

use strict;
use warnings;
use parent qw/Bio::EnsEMBL::Hive::RunnableDB::NotifyByEmail Bio::EnsEMBL::Production::Pipeline::Base/;
use Bio::EnsEMBL::Hive::Utils qw/destringify/;

sub fetch_input {
  my $self = shift;
  
  $self->assert_executable('sendmail');
  
  my $check_latest = $self->jobs('CheckLatest');
  my $download = $self->jobs('DownloadSource');

  my @args = (
    $check_latest->{successful_jobs},
    $check_latest->{failed_jobs},
    $download->{successful_jobs},
    $download->{failed_jobs},
    $self->failed(),
    $self->summary($check_latest),
    $self->summary($download)
  );

  my %errors = $self->logs('ErrorLog');

  my $msg = "Your Versioning Pipeline has finished. We have:\n\n";
  
  foreach my $key (keys %errors) {
    $msg .= $key . $errors{$key} . "\n";
  }

  $msg .= sprintf(<<'MSG', @args);

  * %d sources checked for latest version (%d failed)
  * %d sources with downloaded file (%d failed)

%s

===============================================================================

Full breakdown follows ...

%s

%s

MSG

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
  @jobs = @{$aja->fetch_all_by_analysis_id($id)};
  $_->{input} = destringify($_->input_id()) for @jobs;
  my %passed_sources = map { $_->{input}->{source_name}, 1 } grep { $_->status() eq 'DONE' } @jobs;
  my %failed_sources = map { $_->{input}->{source_name}, 1 } grep { $_->status() eq 'FAILED' } @jobs;
  return {
    analysis => $analysis,
    name => $logic_name,
    jobs => \@jobs,
    successful_jobs => scalar(keys %passed_sources),
    failed_jobs => scalar(keys %failed_sources),
  };
}


sub logs {
  my ($self, $logic_name) = @_;
  my $aa = $self->db->get_AnalysisAdaptor();
  my $aja = $self->db->get_AnalysisJobAdaptor();
  my $analysis = $aa->fetch_by_logic_name($logic_name);
  my $id = $analysis->dbID();
  my @jobs = @{$aja->generic_fetch("j.analysis_id =$id")};
  $_->{input} = destringify($_->input_id()) for @jobs;
  @jobs = sort { $a->{input}->{source_name} cmp $b->{input}->{source_name} } @jobs;
  my %errors = map { $_->{input}->{error}, $_->{input}->{source_name} } @jobs;
  return %errors;
}


sub failed {
  my ($self) = @_;
  my $failed = $self->db()->get_AnalysisJobAdaptor()->fetch_all_by_analysis_id_status(undef, 'FAILED');
  if(! @{$failed}) {
    return 'No jobs failed. Congratulations!';
  }
  my $output = <<'MSG';
The following jobs have failed during this run. Please check your hive's error msg table for the following jobs:

MSG
  foreach my $job (@{$failed}) {
    my $analysis = $self->db()->get_AnalysisAdaptor()->fetch_by_dbID($job->analysis_id());
    my $line = sprintf(q{  * job_id=%d %s(%5d) input_id='%s'}, $job->dbID(), $analysis->logic_name(), $analysis->dbID(), $job->input_id());
    $output .= $line;
    $output .= "\n";
  }
  return $output;
}

my $sorter = sub {
  my $status_to_int = sub {
    my ($v) = @_;
    return ($v->status() eq 'FAILED') ? 0 : 1;
  };
  my $status_sort = $status_to_int->($a) <=> $status_to_int->($b);
  return $status_sort if $status_sort != 0;
  return $a->{input}->{source_name} cmp $b->{input}->{source_name};
};

sub summary {
  my ($self, $data) = @_;
  my $name = $data->{name};
  my $underline = '~'x(length($name));
  my $output = "$name\n$underline\n\n";
  my @jobs = @{$data->{jobs}};
  if(@jobs) {
    foreach my $job (sort $sorter @{$data->{jobs}}) {
      my $source_name = $job->{input}->{source_name};
      $output .= sprintf("  * %s - job_id=%d %s\n", $source_name, $job->dbID(), $job->status());
    }
  }
  else {
    $output .= "No jobs run for this analysis\n";
  }
  $output .= "\n";
  return $output;
}

1;
