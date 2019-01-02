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

package Bio::EnsEMBL::Mongoose::Parser::MIM;
use Modern::Perl;
use Moose;
use Moose::Util::TypeConstraints;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;
use Try::Tiny;
use Bio::EnsEMBL::Mongoose::UsageException;
with 'Bio::EnsEMBL::Mongoose::Parser::Parser','MooseX::Log::Log4perl';

# consumes the omim.txt file
# see also secondary parser consuming mim2gene file
# MIM provides two different datasets in one download; morbidities and gene data
# Variation requires the disease information later on, but it does not play a part in Xrefs

sub read_record { 
  my $self = shift;
  local $/ = '*RECORD*';
  $self->clear_record;
  $self->record->taxon_id(9606); # Mendelian inheritance in man after all.
  
  my $fh = $self->source_handle;
  my $content = <$fh>;
  return unless $content; # first hit is an empty record. It's a convenient parsing falacy above with $/
  my @lines = split "\n",$content;
  # find each subsection, bottle it up and hand off. Yes, this is multi-pass parsing, but the format is horrible and existing parsers are too.
  my @content_buffer = ();
  for my $code (qw/NO TI TX/) {
    my $buffer = 0;
    for (my $i = 0; $i <= $#lines; $i++) {
      my $line = $lines[$i];
      my ($match) = $line =~ /^\*FIELD\*\s*(\w\w)/;
      if ( $match ) {
        if ($buffer == 1) {
          last;
          $buffer = 0;
        } elsif ($match eq $code) {
          $buffer = 1;
        }
      }
      if ($buffer == 1 ) {push @content_buffer,$line}
    }
    unless ( $self->$code(\@content_buffer) ) {
      next;
      @content_buffer = ();
    }
    @content_buffer = ();
  }
  return 1;
}


sub NO {
  my $self = shift;
  my $field = shift;
  my ($accession) = $field->[1] =~ /(\d+)/;
  if ($accession) {
    $self->record->new_accession($accession);
    $self->record->id($accession) ;
    return 1;
  } else {
    # Bio::EnsEMBL::Mongoose::UsageException->throw('No accession in record');
    return;
  }
}

sub TI {
  my $self = shift;
  my $field = shift;
  my $record = $self->record;
  return unless (@$field > 0);
  # use Data::Dumper;
  # print Dumper $field;
  my @bits = split /;;/, join '',splice(@$field,1,scalar @$field); # ;; denotes a separate entry of the same syntax as those before
  my $starter = shift @bits;
  my $symbol;
  ($starter,$symbol) = split /;/,$starter;
  my ($sigil,$id,$gene_name) = $starter =~ /^\s*([\%\*\+\-\#])?(\d+)?\s*(.*)/;
  # $sigil can be * = gene only, nothing, # or % = phenotype only, + = both, ^ = retired
  # retired IDs become xrefs to other MIM IDs if MOVED TO appears. Does not retain retired accessions beyond the MIM ID
  if ($sigil && $sigil eq '^') {
    if ($gene_name =~ /MOVED_TO/) {
      my $xref = Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => 'MIM', id => $id, creator => 'MIM');
      $self->record->add_xref($xref);
    } # else { die you awkward data }
  } elsif (!defined($sigil) || $sigil eq '#' || $sigil eq '%' || $sigil eq '+' ) {
    # this is a description of a phenotype (MIM morbid)
    $record->add_tag('phenotype');
  }
  if ($sigil && ($sigil eq '+' || $sigil eq '*')) {
    # this is a description of a gene
    $record->add_tag('gene');
  }
  $record->id($id) if $id;
  $record->display_label($gene_name) if $gene_name;
  $record->entry_name($symbol) if $symbol;

  foreach my $bit (@bits) {
    my @subbits = split /;/,$bit;
    $gene_name = shift @subbits;
    $record->add_synonym($gene_name) if $gene_name; # maybe put this in another field?
    $record->add_synonym(@subbits) if $#subbits > 0;
  }
}

sub TX {
  my $self = shift;
  my $field = shift;
  my $description;
  $description = join "\n",@$field;
# description sections are not present in all MIM records, free text can be found as well as other sections.
# slurp the lot, it's impossible to determine what is important.
  $self->record->description($description);
  return 1;
}

# These contain mentions of rsIDs useful to variation; more parsing may be required
sub AV {
  my $self = shift;
  my $field = shift;
  my $description = join "\n",@$field;
  $self->record->comment($description);
  return 1;
}
# lots of other fields of no particular interest to Ensembl. Implement if needed
sub RF {return 1;}
sub CS {return 1;} # contains affected tissue types, might be worth parsing.
sub CN {return 1;}
sub CD {return 1;}
sub ED {return 1;}

__PACKAGE__->meta->make_immutable;
