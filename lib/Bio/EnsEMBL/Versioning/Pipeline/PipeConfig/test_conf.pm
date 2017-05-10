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

package Bio::EnsEMBL::Versioning::Pipeline::PipeConfig::test_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');

sub default_options {
    my ($self) = @_;
    
    return {
        # inherit other stuff from the base class
        %{ $self->SUPER::default_options() }, 
        
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
      -logic_name => 'ScheduleSpecies',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::SpeciesFactory',
      -input_ids => [{}],
      -parameters => {
        run_all     => $self->o('run_all'),
      },
      -flow_into => {
         2 => ['DumpFASTA']
      }
    },
    {
      -logic_name => 'DumpFASTA',
      -module => 'Bio::EnsEMBL::Versioning::Pipeline::DumpEnsemblFASTA',
      -parameters => {
       },
      -max_retry_count => 0, # low to prevent pointless dumping repetition
      -hive_capacity => 10,
      -failed_job_tolerance => 25, # percent of jobs that can fail while allowing the pipeline to complete.
      -rc_name => 'default',
    },
    
    ];
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    
    return {
        %{ $self->SUPER::pipeline_wide_parameters() },  # inherit other stuff from the base class
    };
}

1;