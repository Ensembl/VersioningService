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

package Bio::EnsEMBL::Pipeline::PipeConfig::Source_update_conf;

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
        download_dir => '',

        ### Defaults

        pipeline_name => 'source_update_'.time,
        
        email => $self->o('ENV', 'USER').'@sanger.ac.uk',
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
        -module     => 'Bio::EnsEMBL::Pipeline::ScheduleSources',
        -parameters => {
        },
        -input_ids  => [ {} ],
        -max_retry_count  => 10,
        -flow_into  => {
         '2->B'  => ['CheckLatest'],
         '3->B'  => ['DownloadSource'],
         'B->1'  => ['Notify'],
        },
      },

      {
        -logic_name => 'CheckLatest',
        -module     => 'Bio::EnsEMBL::Pipeline::CheckLatest',
        -parameters => {},
        -max_retry_count  => 3,
        -hive_capacity    => 100,
        -rc_name          => 'normal',
        -flow_into  => {
          3 => ['DownloadSource'],
        },
      },

      {
        -logic_name => 'DownloadSource',
        -module     => 'Bio::EnsEMBL::Pipeline::DownloadSource',
        -parameters => {
           download_dir => $self->o('download_dir')
        },
        -max_retry_count  => 3,
        -hive_capacity    => 100,
        -rc_name          => 'normal',
      },

      ####### NOTIFICATION
      
      {
        -logic_name => 'Notify',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::Production::EmailSummaryCore',
        -parameters => {
          email   => $self->o('email'),
          subject => $self->o('pipeline_name').' has finished',
        },
      }
    
    ];
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    
    return {
        %{ $self->SUPER::pipeline_wide_parameters() },  # inherit other stuff from the base class
    };
}

# override the default method, to force an automatic loading of the registry in all workers
sub beekeeper_extra_cmdline_options {
    my $self = shift;
    return "-reg_conf ".$self->o("registry");
}

sub resource_classes {
    my $self = shift;
    return {
      'default' => { 'LSF' => ''},
      'normal'  => { 'LSF' => '-q normal -M 500 -R"select[myens_stag1tok>800 && myens_stag2tok>800 && mem>500] rusage[myens_stag1tok=10:myens_stag2tok=10:duration=10, mem=500]"'},
      'mem'     => { 'LSF' => '-q normal -M 1500 -R"select[myens_stag1tok>800 && myens_stag2tok>800 && mem>1500] rusage[myens_stag1tok=10:myens_stag2tok=10:duration=10, mem=1500]"'},
    }
}

1;
