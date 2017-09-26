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

package Bio::EnsEMBL::Mongoose::Parser::SwissprotFaster;
use Moose;
use Moose::Util::TypeConstraints;

use XML::LibXML::Reader qw(
   XML_READER_TYPE_ELEMENT
   XML_READER_TYPE_END_ELEMENT
   XML_READER_TYPE_TEXT
);

use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;

use Digest::MD5 qw/md5_hex/;

# Consumes Swissprot file and emits Mongoose::Persistence::Records
with 'MooseX::Log::Log4perl', 'Bio::EnsEMBL::Mongoose::Parser::Parser';

# 'uni','http://uniprot.org/uniprot'

has reader => (
    isa => 'XML::LibXML::Reader',
    is => 'rw',
    builder => '_prep_reader',
    lazy => 1
);

# List of uniprot xref sources which are undesirable for computing xrefs
has bad_list => (
    isa => 'HashRef',
    is => 'ro',
    default => sub{ {genetree => 1, go => 1, orthodb => 1 } },
    traits => ['Hash'],
    handles => {
        exclude => 'exists'
    }
);

sub _prep_reader {
    my $self = shift;
    my $reader = XML::LibXML::Reader->new( IO => $self->source_handle ) || die "Nuh uh. Reader stillborn";
    return $reader;
}

sub read_record {
    my $self = shift;
    $self->clear_record;
    my $reader = $self->reader;
    my $health = $reader->nextElement('entry');
    return 0 if $health < 1;
    # Beware of reordering subroutine calls. They are predicated on current state
    my $state = $self->accession; #hard to proceed without an accession of some kind
    # print "accession √\n";
    if ($reader->localName eq 'name') {
        $reader->read; # value
        $self->record->entry_name($reader->value);
        $reader->read; # </name>
        $reader->read; # #blank
    }
    # print "name √\n";
    $self->protein_name;
    # print "protein √\n";
    $self->gene_name;
    # print "gene name √\n";
    $self->taxon;
    # print "taxonomy √\n";
    if ($reader->localName eq 'reference' || $reader->localName eq 'comment') {
        # there are no description or isoform sections here
        $self->description;
        # print "description √\n";
        $self->isoform;
        # print "isoforms √\n";
    }
    $self->xrefs;
    # print "xrefs √\n";
    $self->evidence_level;
    # print "evidence √\n";
    $self->sequence;
    # print "sequence √\n";
    return 1 if $state;
}

sub accession {
    my $self = shift;
    my $reader = $self->reader;
    $reader->nextElement('accession');
    my $nodeType = $reader->nodeType;
    no warnings qq/uninitialized/;
    until ($nodeType == XML_READER_TYPE_ELEMENT && $reader->localName ne 'accession') {
        # <accession>
        $reader->read; # #text
        $self->record->new_accession($reader->value());
        $reader->read; # </accession>
        $reader->read; # #text?
        $reader->read; # <new tag>
    }
    return 1 if defined $self->record->has_accessions;
}

sub protein_name {
    my $self = shift;
    my $reader = $self->reader;
    $reader->nextElement('protein') unless $reader->localName eq 'protein';
    my $depth = $reader->depth;
    $reader->read until ($reader->localName eq 'fullName');
    $reader->read;
    $self->record->display_label($reader->value);
    $reader->read until $reader->depth == $depth;
}

sub gene_name {
    my $self = shift;
    my $reader = $self->reader;
    $reader->read; $reader->read; # step into next section
    if ($reader->localName ne 'gene') { return }
    $reader->read;
    while ($reader->nextSibling() && $reader->localName eq 'name') {
        my $type = $reader->getAttribute('type');
        if ( $type eq 'primary') {
            $reader->read;
            $self->record->gene_name($reader->value);
            $reader->read;
            $reader->read; # white space
        } elsif ($type eq 'synonym') {
            $reader->read;
            $self->record->add_synonym($reader->value);
            $reader->read;
            $reader->read; # white space
        }
    }
}

sub taxon {
    my $self = shift;
    my $reader = $self->reader;
    my $depth = $reader->depth;
    $reader->nextElement('organism') unless $reader->localName eq 'organism';
    $reader->nextElement('dbReference');
    $self->record->taxon_id($reader->getAttribute('id'));
    $reader->read until $reader->depth == $depth;

    $reader->read; # blank

    $reader->read; # next in sequence

}

sub description {
    my $self = shift;
    my $reader = $self->reader;
    my $depth = $reader->depth;
    # $reader->read until $reader->localName eq 'comment' || $reader->localName eq '';
    $reader->nextElement('comment') unless $reader->localName eq 'comment';
    while ($reader->localName eq 'comment' && $reader->getAttribute('type') ne 'function') {
        $reader->nextSibling;
        # printf "%s\n",$reader->localName;
    }
    if ($reader->localName eq 'comment') {
        # printf "%s:%s:%s\n",$reader->nodeType,$reader->localName,$reader->value; # <comment>
        $reader->read; # <text>
        
        $reader->read; # ...
        
        $reader->read; # value
        
        $self->record->description($reader->value);
        # $reader->read; $reader->read;
    }
    $reader->read until $reader->depth == $depth;
    $reader->read; $reader->read;
}

sub isoform {
    my $self = shift;
    my $reader = $self->reader;
    no warnings 'uninitialized';
    until ($reader->localName eq 'dbReference') {
        while ($reader->localName eq 'comment' && $reader->getAttribute('type') ne 'alternative products') {
            # printf "%s:%s:%s   %s\n",$reader->nodeType,$reader->localName,$reader->value,$reader->getAttribute('type');
            $reader->nextSibling; # blank
            $reader->read; # now on a new <comment>
        }
        if ($reader->localName eq 'comment') {
            $self->_parse_isoform($reader);
        }
        $reader->read;
    }
}

sub _parse_isoform {
    my ($self,$reader) = @_;
    # <comment>
    $reader->read; # blank
    $reader->read; # <event>
    $reader->read; # blank
    my $tag = 'comment';
    until ($tag eq 'comment' && $reader->nodeType == XML_READER_TYPE_END_ELEMENT) {
        $reader->read;
        $tag = $reader->localName;
        if ($tag eq 'isoform' && $reader->nodeType == XML_READER_TYPE_ELEMENT) {
            $reader->read;
            $reader->read;
            $reader->read;
            # printf "ISOFORM    %s:%s:%s\n",$reader->nodeType,$reader->localName,$reader->value;
            $self->record->add_isoform($reader->value); # multiple isoforms can be present and are captured
        }
    }
}

# /uni:uniprot/uni:entry/uni:dbReference
sub xrefs {
    my $self = shift;
    my $reader = $self->reader;
    $reader->nextElement('dbReference') if ( $reader->localName ne 'dbReference' && $reader->nodeType == XML_READER_TYPE_ELEMENT);
    my $depth = $reader->depth;
    no warnings 'uninitialized';
    # printf "%s:%s:%s:%s\n",$reader->localName,$reader->nodeType,$reader->readState,$reader->value;
    while ($reader->localName eq 'dbReference' && $reader->depth == $depth) {
        my $source = $reader->getAttribute('type');
        my $id = $reader->getAttribute('id');
        # print "XREF attributes: $source | $id\n";
        my $active = 1;
        my $xref_state = $reader->getAttribute('active');
        if ( $xref_state && $xref_state eq 'N') { $active = 0 };
        # my $last = $reader->getAttribute('last');
        my ($code,$creator,$evidence);
        if ($active == 1 && !$self->exclude(lc $source)) {
            until ($reader->localName eq 'dbReference' && ($reader->nodeType == XML_READER_TYPE_END_ELEMENT || $reader->isEmptyElement)) {
                $reader->read;
                # printf "%s:%s:%s:%s\n",$reader->localName,$reader->nodeType,$reader->readState,$reader->value;
                if ($reader->localName eq 'property' && $reader->getAttribute('type') eq 'evidence') {
                    $evidence = $reader->getAttribute('value');
                    ($code,$creator) = $evidence =~ /(\w+:)(.*)/; # code not currently captured in xref record
                }
                # Hack to replace Uniprot links to Ensembl transcripts, with links to the Ensembl protein they referenced.
                if ($source eq 'Ensembl' && $reader->localName eq 'property' && $reader->getAttribute('type') eq 'protein sequence ID') {
                    $id = $reader->getAttribute('value');
                }
            }
            my $xref = Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => $source, id => $id);
            $xref->creator($creator) if ($creator);
            $self->record->add_xref($xref);

            $reader->read; $reader->read;# reset to next record
        }
        else {
            $reader->read;
            $reader->read until $reader->depth <= $depth; # escape from whatever hell this is
        } 
        # else {
        #     if ($last) {
        #         $self->record->add_xref(Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => 'SwissProtTrembl', id => $last));
        #     }
        # }
        
        # printf "%s:%s:%s:%s\n",$reader->localName,$reader->nodeType,$reader->readState,$reader->value;
    }
}

# /uni:uniprot/uni:entry/uni:proteinExistence/@type
sub evidence_level {
    my $self = shift;
    my $level = 0;
    my $reader = $self->reader;
    $reader->nextElement('proteinExistence') unless $reader->localName eq 'proteinExistence';
    my $evidence = $reader->getAttribute('type');
    my $record = $self->record;

    if ($evidence =~ /evidence at protein level/) { 
        $level = 1; $record->tag(['protein']); 
    } 
    elsif ($evidence =~ /evidence at transcript level/) {
        $level = 2; $record->tag(['transcript']);
    }
    elsif ($evidence =~ /inferred from homology/) {
        $level = 3; $record->tag(['homology']);
    }
    elsif ($evidence =~ /predicted/) {
        $level = 4; $record->tag(['predicted']);
    }
    elsif ($evidence =~ /uncertain/) {
        $level = 5;
    }
    $self->log->trace("Coded to level $level");
    $record->evidence_level($level);
}


sub sequence {
    my $self = shift;
    my $reader = $self->reader;
    $reader->nextElement('sequence');
    my $version = $reader->getAttribute('version');
    $self->record->sequence_version($version) if $version;
    # my $checksum = $reader->getAttribute('checksum'); Replaced with MD5
    $reader->read;
    my $sequence = $reader->value;
    $sequence =~ s/\s+//g;
    if (defined $sequence) {
        $self->record->sequence($sequence);
        $self->record->sequence_length(length($sequence));
        my $checksum = md5_hex($sequence);
        $self->record->checksum($checksum);
    }
}

__PACKAGE__->meta->make_immutable;

1;
