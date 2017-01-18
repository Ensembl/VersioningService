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

package Bio::EnsEMBL::Versioning::Pipeline::PipeConfig::Source_update_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');

sub default_options {
    my ($self) = @_;
    
    return {
        # inherit other stuff from the base class
        %{ $self->SUPER::default_options() }, 
        
        ### OVERRIDE
        
        ### Optional overrides        

        sources => [],

        ### Defaults

        pipeline_name => 'source_update_'.time,
        
        email => $self->o('ENV', 'USER').'@ebi.ac.uk',
    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
      # inheriting database and hive tables' creation
      @{$self->SUPER::pipeline_create_commands}, 
    ];
}

## See diagram for pipeline structure 
sub pipeline_analyses {
    my ($self) = @_;
    
    return [
    
      {
        -logic_name => 'ScheduleSources',
        -module     => 'Bio::EnsEMBL::Versioning::Pipeline::ScheduleSources',
        -parameters => {
        },
        -input_ids  => [ {} ],
        -max_retry_count  => 10,
        -flow_into  => {
          2  => ['CheckLatest']
        },
      },

      {
        -logic_name => 'CheckLatest',
        -module     => 'Bio::EnsEMBL::Versioning::Pipeline::CheckLatest',
        -parameters => {},
        -max_retry_count  => 3,
        -hive_capacity    => 100,
        -rc_name          => 'normal',
        -flow_into  => {
          2 => ['DownloadSource'],
          3 => ['ParseSource'],
        },
      },

      {
        -logic_name => 'DownloadSource',
        -module     => 'Bio::EnsEMBL::Versioning::Pipeline::DownloadSource',
        -parameters => {
        },
        -max_retry_count  => 3,
        -failed_job_tolerance => 25,
        -hive_capacity    => 100,
        -rc_name          => 'normal',
        -flow_into  => {
          2 => ['ParseSource'],
        },
      },

      {
        -logic_name => 'ParseSource',
        -module => 'Bio::EnsEMBL::Versioning::Pipeline::ParseSource',
        -parameters => {

        },
        -max_retry_count => 0, # low to prevent pointless parsing repetition until someone can get attend to the problem.
        -hive_capacity => 10,
        -failed_job_tolerance => 25, # percent of jobs that can fail while allowing the pipeline to complete.
        -rc_name => 'mem',
      },


      ####### NOTIFICATION
      
      {
        -logic_name => 'Notify',
        -module     => 'Bio::EnsEMBL::Versioning::Pipeline::EmailSummary',
        -input_ids  => [ {} ],
        -parameters => {
          email   => $self->o('email'),
          subject => $self->o('pipeline_name').' has finished',
        },
        -wait_for   => [ qw/ScheduleSources CheckLatest DownloadSource ParseSource/ ],
      }
    
    ];
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    
    return {
        %{ $self->SUPER::pipeline_wide_parameters() },  # inherit other stuff from the base class
    };
}

sub resource_classes {
    my $self = shift;
    return {
      'default' => { 'LSF' => ''},
# sanger farm suggested config      # 'normal'  => { 'LSF' => '-q normal -M 500 -R"select[myens_stag1tok>800 && myens_stag2tok>800 && mem>500] rusage[myens_stag1tok=10:myens_stag2tok=10:duration=10, mem=500]"'},
# sanger farm suggested config      # 'mem'     => { 'LSF' => '-q normal -M 1500 -R"select[myens_stag1tok>800 && myens_stag2tok>800 && mem>1500] rusage[myens_stag1tok=10:myens_stag2tok=10:duration=10, mem=1500]"'},
      # EBI farm config
      'normal'  => { 'LSF' => '-q production-rh7 -M 500 -R"select[mem>500] rusage[mem=500]"'},
      'mem'  => { 'LSF' => '-q production-rh7 -M 8000 -R"select[mem>8000] rusage[mem=8000,tmp=90000]"'},
    }
}

1;
