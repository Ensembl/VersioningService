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

=head1 DESCRIPTION

A generic query object to be mapped to various document stores

=cut

package Bio::EnsEMBL::Mongoose::Persistence::Query;
use Moose::Role;

use Config::General;

has config => (
    isa => 'HashRef',
    is => 'rw',
);

has query_string => (
    isa => 'Str',
    is => 'rw',
);

has query_parameters => (
    isa => 'Bio::EnsEMBL::Mongoose::Persistence::QueryParameters',
    is => 'rw',
);

# Runs the supplied query through the query engine.
# Returns the result size if possible
sub query {
    
};


# Should iterate through results internally and emit the next result until there are no more.
sub next_result {
    
};

# Refers to a QueryParameters object to construct a suitable query in the diallect of choice.
sub build_query {
    
}

1;
