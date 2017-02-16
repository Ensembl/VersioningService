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

=pod

=head1 NAME

package Bio::EnsEMBL::Versioning::Pipeline::PipeConfig::Xref_pipeline_conf;


=head1 DESCRIPTION
Pipeline to generate Xref for all core species
Needs a LOD mapping file to function and at least 100 GB of scratch space.

=cut


package Bio::EnsEMBL::Versioning::Pipeline::PipeConfig::Xref_pipeline_conf;
use strict;
use parent 'Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf';
use Bio::EnsEMBL::ApiVersion qw/software_version/;

sub default_options {
  my $self = shift;
  return {
    %{ $self->SUPER::default_options() },
    xref => 1,
    config_file => $ENV{MONGOOSE}.'/conf/xref_LOD_mapping.json',
    release => software_version(),
    pipeline_name => 'xref_pipeline_'.time,
    species => [],
    division => [],
    antispecies =>[],
    run_all => 0, #always run every species
    ## Set to '1' for eg! run
    #   default => OFF (0)
    'eg'  => 0,
  }
}

sub pipeline_wide_parameters {
  my $self = shift;
  return {
    %{ $self->SUPER::pipeline_wide_parameters() },
    base_path => $self->o('base_path'),
    'sub_dir'       => $self->o('base_path'),
  }
}

sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class
        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    };
}


sub pipeline_analyses {
  my $self = shift;
  return [ 
    {
      -logic_name => 'LogSummaryBegin',
      -module => 'Bio::EnsEMBL::Versioning::Pipeline::LogSummary',
      -input_ids => [{}], # required for automatic seeding
      -parameters => {
         begin_run => 1,
         end_run => 0,
         }, 
       -rc_name       => 'default', 
       -flow_into  => {
         2  => ['ScheduleSpecies']
         },
     }, 
    {
      -logic_name => 'ScheduleSpecies',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::SpeciesFactory',
      -parameters => {
         species     => $self->o('species'),
         antispecies => $self->o('antispecies'),
         division    => $self->o('division'),
         run_all     => $self->o('run_all'),
      },
      -flow_into => {
         2 => ['DumpRDF','DumpFASTA']
      }
    },
    {
      -logic_name => 'DumpRDF',
      -module => 'Bio::EnsEMBL::Versioning::Pipeline::RDFDumper',
      -parameters => {
       },
      -max_retry_count => 0, # low to prevent pointless dumping repetition
      -hive_capacity => 10,
      -failed_job_tolerance => 25, # percent of jobs that can fail while allowing the pipeline to complete.
      -rc_name => 'default',
      -flow_into  => {
         3  => ['LogSummaryEnd']
      },
    },
    {
      -logic_name => 'DumpFASTA',
      -module => 'Bio::EnsEMBL::Versioning::Pipeline::DumpEnsemblFASTA',
      -max_retry_count => 1,
      -hive_capacity => 4,
      -failed_job_tolerance => 25,
      -flow_into => {
        2 => ['CheckCheckSum']
      }
    },
    {
      -logic_name => 'CheckCheckSum',
      -module => 'Bio::EnsEMBL::Versioning::Pipeline::CheckCheckSum',
      -max_retry_count => 0,
      -hive_capacity => 10,
      -failed_job_tolerance => 1,

    },
    {
      -logic_name => 'LogSummaryEnd',
      -module     => 'Bio::EnsEMBL::Versioning::Pipeline::LogSummary',
      -parameters => {
         begin_run => 1,
         end_run => 1,
       },
      -wait_for   => [ qw/DumpRDF DumpFASTA/ ],
    },
  ];
}

sub beekeeper_extra_cmdline_options {
    my $self = shift;
    return "-reg_conf ".$self->o("registry");
}

sub resource_classes {
my $self = shift;
  return {
    'dump'      => { LSF => '-q normal -M10000 -R"select[mem>10000] rusage[mem=10000]"' },
    'verify'    => { LSF => '-q small -M1000 -R"select[mem>1000] rusage[mem=1000]"' }
  }
}

1;
