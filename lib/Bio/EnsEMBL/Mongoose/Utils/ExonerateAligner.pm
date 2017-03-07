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

# Exonerate wrapper

package Bio::EnsEMBL::Mongoose::Utils::ExonerateAligner;

use Moose;
use Config::General;
use Moose::Util::TypeConstraints;
use Bio::EnsEMBL::Mongoose::UsageException;
use Bio::EnsEMBL::Mongoose::Utils::AlignmentMethodFactory;

extends 'Bio::EnsEMBL::Mongoose::Utils::Aligner';

# flags that almost always get set in exonerate
# xref:ENSG00000157764:ENST00000497784:190062:205438:190062:106:190168:0:190062: M 190062:950310
has conf => (is => 'rw',isa => 'HashRef', default => sub {{
  ryo => q(xref\\t%qi\\t%ti\\t%ei\\t%ql\\t%tl\\t%qab\\t%qae\\t%tab\\t%tae\\t%C\\t%s\\n),
  showalignment => 'false',
  showvulgar => 'false',
  gappedextension => 'false',
  model => 'affine:local',
  subopt => 'no'
}});

# These can be set directly, or via a presets in AlignmentMethodFactory with set_method(). Might belong in generic Aligner class in future
has query_threshold => (is => 'rw', isa => 'Num'); # %id match
has target_threshold => (is => 'rw', isa => 'Num'); # %id match from target to query
has limit => (is => 'rw', isa => 'Int'); # i.e. number of results to return, --bestn

has chunk_cardinality => (is => 'rw', isa => 'Int'); # number of jobs being run on the query file
has execute_on_chunk => (is => 'rw', isa => 'Int'); # portion of query file to work on

has method_factory => (is => 'ro', default => sub{{ Bio::EnsEMBL::Mongoose::Utils::AlignmentMethodFactory->new() }});

has result_filter => (
  traits => ['Code'], 
  is => 'rw', 
  isa => 'CodeRef', 
  default => sub { \&_filter_function }, 
  handles => { output_filter => 'execute_method' }
);

sub BUILD {
  my $self = shift;
  $self->exe('exonerate');
}

# Selector of result filtering method
sub set_method {
  my $self = shift;
  my $method = shift;
  if ($method and $self->method_factory->valid_method($method)) {
    my $params = $self->method_factory->fetch_method($method);
    $self->query_threshold($params->{query_score});
    $self->target_threshold($params->{target_score});
    $self->limit($params->{n});
  } else {
    Bio::EnsEMBL::Mongoose::UsageException->throw("No method $method available. Valid methods are ".join(',',$self->method_names()) );
  }
}

# Construct exec string
sub build_command {
  my $self = shift;
  my $n = $self->limit;
  
  my %conf = %{$self->conf};
  my $command_string = sprintf "%s --showalignment %s --showvulgar %s --ryo '%s' --gappedextension %s --model %s --bestn %s --subopt %s --query %s --target %s %s",
    $self->exe,
    $conf{showalignment},
    $conf{showvulgar},
    $conf{ryo},
    $conf{gappedextension},
    $conf{model},
    $n,
    $conf{subopt},
    $self->source,
    $self->target,
    $self->user_parameters;
  if (defined $self->chunk_cardinality) {
    my $chunking = sprintf "--querychunktotal %s --querychunkid %s",$self->chunk_cardinality,$self->execute_on_chunk;
    $command_string .= $chunking;
  }
  return $command_string;
}

sub _filter_function {
  my $self = shift;
  my $content = shift;
  my @hits = grep {$_ =~ /^xref/} split "\n",$content; # not all lines in output are alignments
  my %results;
  while (my $hit = shift @hits) {
    my (undef,$ens_id,$target_id,$equiv,$length,$target_length,$query_start,$query_end,$target_start,$target_end,$cigar,$score) = split /\t/, $hit;
    my $query_identity = sprintf "%.2f", $equiv / $length;
    my $target_identity = sprintf "%.2f", $equiv / $target_length;
    if ($query_identity >= $self->query_threshold && $target_identity >= $self->target_threshold) {
      $results{$ens_id.':'.$target_id} = {score => $score, query_identity => $query_identity, target_identity => $target_identity};
    }
  }
  return \%results;
}


1;