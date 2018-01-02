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

=cut

package Bio::EnsEMBL::Mongoose::Persistence::SolrFeeder;

use Moose;
use Moose::Util::TypeConstraints;

use Bio::EnsEMBL::Mongoose::Persistence::Record;
use LWP::UserAgent;
use MIME::Base64 qw/encode_base64 decode_base64/;

with 'Bio::EnsEMBL::Mongoose::Persistence::DocumentStore';
with 'MooseX::Log::Log4perl';

has 'commit_interval' => ( isa => 'Int', is => 'ro', default => 1000 );
has 'docs' => ( isa => 'ArrayRef', is => 'rw', traits  => ['Array'], default => sub { [] }, handles => {
  clear_docs => 'clear',
  add_doc => 'push',
  is_docs_empty => 'is_empty',
  docs_count => 'count'
});
has 'lwp' => ( isa => 'LWP::UserAgent', is => 'ro', default => sub {
  my $lwp = LWP::UserAgent->new();
  $lwp->default_header('Content-Type', 'application/xml');
  return $lwp;
});

sub store_record {
  my $self = shift;
  my $record = shift;
  
  my $doc = {
    id => $record->primary_accession(),
    accessions => $record->accessions(),
    taxon => $record->taxon_id(),
    json => $self->compress_json({%$record})
  };
  
  $self->add_doc($doc);
  
  if($self->docs_count() == $self->commit_interval()) {
    $self->commit();
  }
  
  return;
}

sub commit {
  my ($self) = @_;
  #If it wasn't empty we can commit the buffer which means post
  if(! $self->is_docs_empty()) {
    $self->log->info('Writing out docs @ '.$self->docs_count());
    my $query_string = q{};
    $query_string .= "<add>\n";
    foreach my $doc (@{$self->docs()}) {
      $query_string .= "<doc>\n";
      foreach my $key (keys %{$doc}) {
        my $value = $doc->{$key};
        if(ref($value) eq 'ARRAY') {
          $query_string .= "<field name='${key}'>${_}</field>\n" for @{$value};
        }
        else {
          $query_string .= "<field name='${key}'>${value}</field>\n";
        }
      }
      $query_string .= "</doc>\n";
    }
    $query_string .= "</add>\n";
    $self->_send_to_solr(\$query_string);
    $self->clear_docs();
    $self->log->info('Done');
  }
  return;
}

sub _send_to_solr {
  my ($self, $ref) = @_;
  my $url = 'http://127.0.0.1:8983/solr/swissprot_mongoose/update?commit=true';
  my $response =  $self->lwp()->post($url, 'Content-type' => 'text/xml', Content => $$ref);
  if(!$response->is_success()) {
    warn "boo";
    warn $response->status_line;
    warn $response->content;
    # warn $$ref;
    Bio::EnsEMBL::Mongoose::IOException->throw("All is not well");
  }
  return;
}


__PACKAGE__->meta->make_immutable;

1;
