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

package Bio::EnsEMBL::Mongoose::Parser::ZFIN;
use Moose;
use Moose::Util::TypeConstraints;
use Bio::EnsEMBL::Mongoose::IOException qw(throw);

use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;

# Tri-modal parser for the three different varieties of TSV provided by ZFIN.
# This could just as well be done by three separate "sources" and parsers, but leads to code bloatage.
has mode => ( isa => 'Str', is => 'ro', lazy => 1, builder => 'identify_file');
has peek_buffer => (isa => 'Maybe[Str]', is=> 'rw', lazy => 1, builder => '_prime_pump', predicate => 'charged_buffer', clearer => 'empty_buffer');

sub _prime_pump {
  my $self = shift;
  my $fh = $self->source_handle;
  return <$fh>;
}

sub next_line {
  my $self = shift;
  my $fh = $self->source_handle;
  my $line = $self->peek_buffer;
  chomp $line;
  my $content = <$fh>;
  if ($content) {
    $self->peek_buffer($content) ;
  } else {
    $self->empty_buffer;
  }
  return $line;
}

with 'Bio::EnsEMBL::Mongoose::Parser::Parser','MooseX::Log::Log4perl';

sub identify_file {
  my $self = shift;
  my $filename = $self->source_file;
  return 'aliases' if $filename =~ /aliases.txt$/;
  return 'uniprot' if $filename =~ /uniprot.txt$/;
  return 'refseq' if $filename =~ /refseq.txt$/;
}

# Note that consecutive lines can contain more information pertaining to the same record

sub extract_id {
  my $self = shift;
  return unless $self->charged_buffer && defined $self->peek_buffer;
  my ($id) = split "\t",$self->peek_buffer;
  return $id;
}

sub fetch_all_matches {
  my $self = shift;
  my $id = $self->extract_id;
  return unless $id;
  my @matches;
  # until peek buffer doesn't contain the same ZFIN ID
  # keep treating it as the same record
  while ($self->extract_id && $id eq $self->extract_id) {
    push @matches, $self->next_line;
  }
  return \@matches;
}


sub read_record {
  my $self = shift;
  my $fh = $self->source_handle;
  $self->peek_buffer; # Force builder to fire. Calling the predicate does not trigger a lazy load :/

  my $matches = $self->fetch_all_matches;
  if ($matches) {
    $self->clear_record;
    my $record = $self->record;
    $record->taxon_id(7955); # this is Zebrafish data
    my $first = 1;
    # Iterate through all rows with the same ZFIN ID
    foreach my $match (@$matches) {
      my @fields = split "\t",$match;
      
      if ($self->mode eq 'aliases') {
        my ($zfin_id,$name,$symbol,$old_name,$so_term) = @fields;
        if ($first == 1) {
          $record->id($zfin_id);
          $record->accessions([$zfin_id]);
          $record->add_synonym($old_name);
          $record->display_label($symbol);
          $record->entry_name($name);
          $first = 0;
        } else {
          $record->add_synonym($old_name);
        }
      } 
      elsif ($self->mode eq 'uniprot' || $self->mode eq 'refseq') {
        my ($zfin_id,$so_term,$symbol,$xref_id) = @fields;
        
        if ($first == 1) {
          $record->id($zfin_id);
          $record->accessions([$zfin_id]);
          $record->display_label($symbol);
          $first = 0;
        }
        $record->add_xref(Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(
          source => $self->mode, id => $xref_id, creator => 'ZFIN'
        ));
      }

    }
    return 1;
  }
  else {
    return;
  }
}

__PACKAGE__->meta->make_immutable;

1;
