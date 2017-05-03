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

=head1 DESCRIPTION

A "record" representing one entity in a database. This format can be stored in a
Lucene-like document store, and dumped. It acts as the single unifying format for 
the multitude of different formats of data Ensembl imports. As such the record 
contains a number of fields that do not always make sense in particular contexts.

We leave it to the serializers to decide what to do the record when it is dumped out.

External references are handled by the RecordXref object type and are attached to
the record. The record is transformed into JSON for storage and transformed back again
into this object type during queries.

=cut

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

has chromosome => (
    isa => 'Str',
    is => 'rw',		   
);

has strand => (
    isa => 'Int',
    is => 'rw',
);

# A genomic location string, such as 6:1000-1010
has region => (
    isa => 'Str',
    is => 'rw',
);

# A name for the gene this record refers to. Useful when this record is not itself a gene, e.g. Uniprot
has gene_name => (
    isa => 'Str',
    is => 'rw',
);

# A collection of properties to describe coding sequences of a gene or transcript. 
# Needed for specific sources which we perform positional overlap calculations on

has transcript_start => (
    isa => 'Int',
    is => 'rw',
);

has transcript_end => (
    isa => 'Int',
    is => 'rw',
);

has cds_start => (
    isa => 'Int',
    is => 'rw',
    default => 0
);

has cds_end => (
    isa => 'Int',
    is => 'rw',
    default => 0
);

has exon_starts => (
    isa => 'ArrayRef[Int]',
    is => 'rw',
    traits => ['Array']
);

has exon_ends => (
    isa => 'ArrayRef[Int]',
    is => 'rw',
    traits => ['Array']
);
# End collection of properties.


# Name of the protein this record refers to, usually when this record is not itself a protein
# See also display_label for those cases. Main use is for establishing equivalence in a multi-typed source
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
        get_accession => 'get',
        new_accession => 'push'
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
# Lists accessions which refer to structural isoforms, such as is found in Uniprot data
# Does not contain the actual isoforms themselves.
has isoforms => (
    isa => 'ArrayRef[Str]',
    is => 'rw',
    traits => ['Array'],
    handles => {
        add_isoform => 'push'
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
# Long form description of the function of this record
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
    isa => 'Str',
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
