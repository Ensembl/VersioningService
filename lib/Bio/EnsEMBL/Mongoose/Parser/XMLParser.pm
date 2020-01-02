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

package Bio::EnsEMBL::Mongoose::Parser::XMLParser;
use Moose::Role;
use Moose::Util::TypeConstraints;

use XML::LibXML;
use XML::LibXML::XPathContext;
use XML::LibXML;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;
use Bio::EnsEMBL::Mongoose::IOException;
use Try::Tiny;

# Consumes Swissprot file and emits Mongoose::Persistence::Records
# Should be generic with an override of slurp_content() to suit wrapping tags

subtype 'XML::LibXML::DOM' => as 'Object';

coerce 'XML::LibXML::DOM' => from 'Str' => via {
  my $xml_chunk = $_;
  try {  
    XML::LibXML->load_xml( string => $xml_chunk, huge => 1);
  } catch {
    Bio::EnsEMBL::Mongoose::IOException->throw("XML parsing error: $_");
  };
};

has xml_document => (
    is => 'rw',
    isa => 'XML::LibXML::DOM',
    coerce => 1,
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->content;
    },
    clearer => 'flush_document',
);

has xpath_context => (
    is => 'ro',
    isa => 'XML::LibXML::XPathContext',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $xpc = XML::LibXML::XPathContext->new();
        $xpc->registerNs($self->short_namespace,$self->namespace);
        return $xpc;
    }
);

has namespace => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);

has short_namespace => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);

has content => (
    is => 'rw',
    isa => 'Str'
);

has xml_header => (
    is => 'rw',
    isa => 'Str',
);

has top_tag => (
    is => 'ro',
    isa => 'Str',
    default => 'uniprot',
    lazy => 1,
);
has xml_footer => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $footer = '</'.$self->top_tag.'>';
        return $footer;
    }
);


with 'Bio::EnsEMBL::Mongoose::Parser::Parser', 'MooseX::Log::Log4perl';

sub read_record {
    my $self = shift;
    my $slurp;
    try {
        $slurp = $self->slurp_content;
    } catch {
        Bio::EnsEMBL::Mongoose::IOException->throw(
            sprintf "Parsing failed fatally: %s\n Current block: %s\nfrom file: %s\n File position: %s\n",
                $_, $self->content, $self->source_file, tell $self->source_handle);
    };
    if (!$slurp) {
        $self->log->debug("EOF reached.");
        $self->flush_document; 
        return; 
    }
    $self->clear_record;
    $self->log->trace("Reading XML section");
    my $read_state = $self->node_sieve();
    $self->flush_document; # Make sure XML does not pollute next iteration
    return $read_state;
}


sub slurp_content {
    my $self = shift;
    my $handle = $self->source_handle;
    local $/ = '</entry>';
    my $content = <$handle>;
    $self->log->trace($content);
    unless ($self->xml_header) {
        $content =~ s/(.*)(?=<entry[^>]*?>)//s;
        $self->xml_header($1);
    }
    $self->log->trace($self->xml_header); 
    my $tag = $self->top_tag;
    # Beyond the last </entry> is a </uniprot> or a </uniparc>
    # We can skip this safely
    if ($content =~ /<\/$tag>$/) {
        $self->log->trace("Found end of XML file");
        return;
    }
    $self->content($self->xml_header.$content.$self->xml_footer);
    return 1;
}

# General method for getting exactly one text node back.

sub xpath_to_value {
    my $self = shift;
    my $xpath = shift;
    
    my $node_list = $self->xpath_context->findnodes($xpath, $self->xml_document);
    if ($node_list->size > 0) {
        return $node_list->shift->textContent;
    } else {
        $self->log->trace("Xpath returned nowt, ".$xpath);
        return;
    }
}

1;
