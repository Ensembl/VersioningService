=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Mongoose::Persistence::RecordXref;

use Moose;

# source of the xref, not necessarily the source that made the link. 
# Also the key for namespace of URIs of the xref
has source => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

# name/id from the external source
has id => (
    isa => 'Str',
    is => 'rw',
    required =>1,
);

# refers to whether a link is retired or not
has active => (
    isa => 'Bool',
    is => 'ro',
    required => 1,
    default => 1,
);

has version => (
    isa => 'Str',
    is => 'ro',
);

# who said this link exists. Needed where xref sources are aggregators themselves.
# name matched with dublin core
has creator => (
    isa => 'Str',
    is => 'rw',
);

sub TO_JSON {
    return {%{shift()}};
}

__PACKAGE__->meta->make_immutable;

1;
