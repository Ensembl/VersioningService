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

=head1 DESCRIPTION

A query template in object form. 
Specify: source, a list of ids, an evidence level, maximum returned results (when you want more than 10),
or a list of taxon IDs to specify species. Species name is also valid, but will be checked against
the NCBI taxonomy, and hence is not a solution for species that share taxa.

=cut

package Bio::EnsEMBL::Mongoose::Persistence::QueryParameters;

# A holding object for query parameters, prior to translation into 
# search engine lingo. 

use Moose;
use Moose::Util::TypeConstraints;

has source => (
    isa => 'Obj',  
    is => 'ro',
    
);

has output_format => (
    isa => enum([qw( FASTA JSON RDF EnsemblRDF)]),
    is => 'ro',
    default => 'FASTA',
);

has ids => (
    isa => 'ArrayRef[Str]',
    is => 'rw',
    default => sub {[]},
    traits => ['Array'],
    handles => {
        count_ids => 'count',
        all_ids => 'elements'
    },
);

has id_type => (
    isa => 'Str',
    is => 'rw',
);
# accessions, primary_accession, gene_name

has evidence_level => (
    isa => 'Str',
    is => 'rw',
);

has result_size => (
    isa => 'Int',
    is => 'rw',
    default => 10,
);

# Revision required when species collections are an issue.
has taxons => (
    isa => 'ArrayRef[Int]',
    is => 'rw',
    default => sub {[]},
    traits => ['Array'],
    handles => {
        constrain_to_taxons => 'elements',
        has_taxons => 'count',
    }
);

has species_name => (
    isa => 'Str',
    is => 'rw',
    clearer => 'clear_species_name',
);

has checksum => (
    isa =>'Str',
    is => 'rw',
);

1;
