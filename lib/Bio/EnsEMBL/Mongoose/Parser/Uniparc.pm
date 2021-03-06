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

=cut

package Bio::EnsEMBL::Mongoose::Parser::Uniparc;
use Moose;
use Moose::Util::TypeConstraints;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;

extends 'Bio::EnsEMBL::Mongoose::Parser::SwissprotFaster';
# Consumes Swissprot file and emits Mongoose::Persistence::Records
with 'MooseX::Log::Log4perl';

# Replace Swissprot read_record with a shorter version suitable for Uniparc's limited fields
sub read_record {
    my $self = shift;
    $self->clear_record;
    my $reader = $self->reader;
    my $health = $reader->nextElement('entry');
    return 0 if $health < 1;

    $self->accession;
    $self->xrefs;
    $self->sequence;
}

# # Filtering out only Ensembl Xrefs for the purposes of the old xref pipeline.
# sub xrefs {
#     my $self = shift;
#     # /uni:uniparc/uni:entry/uni:dbReference[@type="ENSEMBL"]
#     my $node_list = $self->xpath_context->findnodes('/uni:uniparc/uni:entry/uni:dbReference[@type="ENSEMBL"]',$self->xml_document);
    
#     my $record = $self->record;
#     $node_list->foreach( sub {
#         my $node = shift;
#         my @attributes = $node->attributes();
#         my ($source,$id,$active,$last);
#         foreach my $attr (@attributes) {
#             if ($attr->nodeName eq 'type') {$source = $attr->value}
#             elsif ($attr->nodeName eq 'id') {$id = $attr->value}
#             elsif ($attr->nodeName eq 'active') {
#                 $active = ($attr->value eq 'Y') ? 1 : 0;
#             }
#             elsif ($attr->nodeName eq 'last' && !$active) {
#                 # Only really interested in last seen in the event that an ID has been retired.
#                 $last = $attr->value;
#             }
#         }
#         unless (defined($source) && defined($id) && defined($active)) { $self->log->debug(sprintf 'Faulty xref: %s,%s,%s,%s',$source,$id,$active,$last); return; }
#         my %attribs = (source => $source, id => $id, active => $active);
#         if ($last) { $attribs{version} = $last }
#         my $xref = Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(%attribs);
        
#         $record->add_xref($xref);
#     });
# }


1;
