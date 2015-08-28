# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#      http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package Bio::EnsEMBL::Mongoose::Persistence::Record;
use Moose;

use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;

# primary internal identifier, e.g. ENSG/UPI:
has id => (
    isa => 'Str',
    is => 'rw',
    required => 0,
);

has sequence => (
    isa => 'Str',
    is => 'rw',
);

has sequence_length => (
    isa => 'Int',
    is => 'rw',
);

# Sequence version is independent of record version for some sources
has sequence_version => (
    isa => 'Int',
    is => 'rw',
);

# A genomic location string, such as 6:1000-1010
has region => (
    isa => 'Str',
    is => 'rw',
);

# A name for the gene this refers to
has gene_name => (
    isa => 'Str',
    is => 'rw',
);

# Name of the protein this record refers to
has protein_name => (
    isa => 'Str',
    is => 'rw',
);

has entry_name => (
    isa => 'Str',
    is => 'rw',
);

# first accession is the "primary" accession
has accessions => (
    isa => 'ArrayRef[Str]',
    is => 'rw',
    traits => ['Array'],
    predicate => 'has_accessions',
    handles => {
        'get_accession' => 'get'
    }
);

# labels that are other names than the gene_name
has synonyms => (
    isa => 'ArrayRef[Str]',
    is => 'rw',
    traits => ['Array'],
    handles => {
        add_synonym => 'push'
    }
);

# links however tenuous to external resources that describe the same entity
has xref => (
    isa => 'ArrayRef[Bio::EnsEMBL::Mongoose::Persistence::RecordXref]',
    is => 'rw',
    traits => ['Array'],
    default => sub {[]},
    handles => {
        add_xref => 'push',
        remove_xref => 'pop',
        grep_xrefs => 'grep',
        map_xrefs => 'map',
        count_xrefs => 'count',
    }
);

# The favourite accession/id/name for displaying to users
has display_label => (
    isa => 'Str',
    is => 'rw',
);

has description => (
    isa => 'Str',
    is => 'rw',
);

# Comment field is for supporting text that will be carried through to the browser.
has comment => (
    isa => 'Str',
    is => 'rw',
);

# For sequence equality matching
has checksum => (
    isa => 'Str',
    is => 'rw',
);

has version => (
    isa => 'Int',
    is => 'rw',
);

# instead of species, less ambiguous.
has taxon_id => (
    isa => 'Int',
    is => 'rw',
    predicate => 'has_taxon_id',
);

has schema_version => (
    isa => 'Int',
    is => 'rw',
);

# meaning specific to source. Mainly a uniprot property
has evidence_level => (
    isa => 'Int',
    is => 'rw',
);
# 1 = Protein level
# 2 = Transcript level
# 3 = Support by homology
# 4 = Predicted
# 5 = Uncertain

# Certain sources (OMIM) have multiple data types in one bundle. These can be differentiated by tagging them.
# For OMIM, look for 'phenotype' and 'gene', both can be present
has tag => (
    isa => 'ArrayRef[Str]',
    is => 'rw',
    traits => ['Array'],
    handles => { add_tag => 'push' },
);

# Place to put warnings about why this record may not be reliable.
has suspicion => (
    isa => 'Str',
    is => 'rw',
);

sub TO_JSON {
    return {%{shift()}};
}

sub primary_accession {
    my $self = shift;
    my $accession = $self->get_accession(0);
    return $accession if $accession;
    return;
}

__PACKAGE__->meta->make_immutable;

1;