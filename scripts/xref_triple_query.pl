use strict;

use Modern::Perl;
use RDF::Query::Client;
use Bio::EnsEMBL::RDF::RDFlib qw/compatible_name_spaces/;
use Bio::EnsEMBL::Registry;

my $ens_host = 'mysql-ensembl-mirror.ebi.ac.uk';
my $ens_port = 4240;
my $ens_user = 'anonymous';

Bio::EnsEMBL::Registry->load_registry_from_db( -host => $ens_host, -port => $ens_port, -user => $ens_user, -db_version => 84);

my $triplestore = 'http://127.0.0.1:8890/sparql';

# get_em_all();

my $transcript_adaptor = Bio::EnsEMBL::Registry->get_adaptor('human','core','transcript');
my $transcripts = $transcript_adaptor->fetch_all();

foreach my $transcript (@$transcripts) {
  my $id = $transcript->stable_id;

  my $result_hash = recurse_xrefs($id);

  if (keys %$result_hash > 0) {
    printf "%s has %s xrefs\n",$id,scalar keys %$result_hash;
    my $result_list = join ',', map {@{ $result_hash->{$_} }} keys %$result_hash;
    print  "$result_list\n";
  } else {
    # printf "%s has no xrefs\n", $id;
  }
  # last;
}
use Data::Dumper;

sub recurse_xrefs {
  my $id = shift;
  my $result_hash = shift;
  return if (defined $result_hash && exists $result_hash->{$id});
  my $query = sprintf qq(%s\nSELECT DISTINCT ?xref_label FROM <http://xrefs/> {
    ?o dc:identifier "%s" .
    ?e term:refers-to* ?o .
    ?e dc:identifier ?xref_label.
    }
    }), compatible_name_spaces(),$id;
  # print $query."\n";
  my $sparql = RDF::Query::Client->new($query);
  my $result_iterator = $sparql->execute($triplestore);
  my $error = $sparql->error();
  if ($error) { die $error }
  my @xrefs = ();
  while (my $result = $result_iterator->next) {
    # print Dumper $result_iterator;
    my $string = $result->{xref_label}->as_string;
    $string =~ s/"//g;
    push @xrefs,$string;
  }
  if (scalar @xrefs > 0) {
    $result_hash->{$id} = \@xrefs;
  }
  foreach my $nested_id (@xrefs) {
    my $nested_hash = recurse_xrefs($nested_id,$result_hash);
    foreach my $k (keys %$nested_hash) {
      $result_hash->{$k} = $nested_hash->{$k};
    }
  }
  return $result_hash;
}


sub get_em_all {
  my $query = "PREFIX obo: <http://purl.obolibrary.org/obo/>
PREFIX sio: <http://semanticscience.org/resource/>
PREFIX pirsf: <http://purl.uniprot.org/pirsf/>
PREFIX oa: <http://www.w3.org/ns/oa#>
PREFIX blastprodom: <http://purl.uniprot.org/prodom/>
PREFIX uniprot_gn: <http://purl.uniprot.org/uniprot/>
PREFIX identifiers: <http://identifiers.org/>
PREFIX gene3d: <http://purl.uniprot.org/gene3d/>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX xml: <http://www.w3.org/XML/1998/namespace>
PREFIX scanprosite: <http://purl.uniprot.org/prosite/>
PREFIX prints: <http://purl.uniprot.org/prints/>
PREFIX exon: <http://rdf.ebi.ac.uk/resource/ensembl.exon/>
PREFIX dc: <http://purl.org/dc/elements/1.1/>
PREFIX dcat: <http://www.w3.org/ns/dcat#>
PREFIX prodom: <http://purl.uniprot.org/prodom/>
PREFIX dctypes: <http://purl.org/dc/dcmitype/>
PREFIX dcmit: <http://purl.org/dc/dcmitype/>
PREFIX superfamily: <http://purl.uniprot.org/supfam/>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX tigrfam: <http://purl.uniprot.org/tigrfams/>
PREFIX prosite_patterns: <http://purl.uniprot.org/prosite/>
PREFIX faldo: <http://biohackathon.org/resource/faldo#>
PREFIX void: <http://rdfs.org/ns/void#>
PREFIX transcript: <http://rdf.ebi.ac.uk/resource/ensembl.transcript/>
PREFIX ensemblvariation: <http://rdf.ebi.ac.uk/terms/ensemblvariation/>
PREFIX hmmpanther: <http://purl.uniprot.org/panther/>
PREFIX term: <http://rdf.ebi.ac.uk/terms/ensembl/>
PREFIX prov: <http://www.w3.org/ns/prov#>
PREFIX interpro: <http://purl.uniprot.org/interpro/>
PREFIX pfam: <http://purl.uniprot.org/pfam/>
PREFIX pav: <http://purl.org/pav/>
PREFIX smart: <http://purl.uniprot.org/smart/>
PREFIX ensembl: <http://rdf.ebi.ac.uk/resource/ensembl/>
PREFIX pfscan: <http://purl.uniprot.org/profile/>
PREFIX dcterms: <http://purl.org/dc/terms/>
PREFIX ident_type: <http://idtype.identifiers.org/>
PREFIX oban: <http://purl.org/oban/>
PREFIX dataset: <http://rdf.ebi.ac.uk/dataset/ensembl/>
PREFIX prosite_profiles: <http://purl.uniprot.org/prosite/>
PREFIX taxon: <http://identifiers.org/taxonomy/>
PREFIX panther: <http://purl.uniprot.org/panther/>
PREFIX uniparc: <http://purl.uniprot.org/uniparc/>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX protein: <http://rdf.ebi.ac.uk/resource/ensembl.protein/>
PREFIX ensembl_variant: <http://rdf.ebi.ac.uk/resource/ensembl.variant/>
PREFIX freq: <http://purl.org/cld/freq/>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX hamap: <http://purl.uniprot.org/hamap/>
SELECT DISTINCT ?e_label ?e ?e_source ?xref_label ?o ?source FROM <http://xrefs/> {
    ?e dc:identifier ?e_label .
    ?e dcterms:source ?e_source .
    ?o term:refers-to* ?e .
    ?o dc:identifier ?xref_label.
    OPTIONAL { ?o dcterms:source ?source . }
    OPTIONAL { ?e dcterms:source ?e_source . }
}";

  my $sparql = RDF::Query::Client->new($query);
  my $result_iterator = $sparql->execute($triplestore);
  my $error = $sparql->error();
  if ($error) { die $error }
  my @xrefs = ();
  while (my $result = $result_iterator->next) {
    printf "%s\t%s\t%s\t%s\n",$result->{e_source}->as_string, $result->{e_label}->as_string, $result->{source}->as_string, $result->{xref_label}->as_string;
  }
}