package Bio::EnsEMBL::Mongoose::Persistence::DocumentStore;

use Moose::Role;

use JSON::XS qw/encode_json decode_json/;
use PerlIO::gzip;
use MIME::Base64 qw/encode_base64 decode_base64/;
use Sereal::Encoder qw/encode_sereal/;
use Sereal::Decoder qw/decode_sereal/;

use Bio::EnsEMBL::Mongoose::IOException;

# Lingo here is mainly themed to match Lucy/Lucene terminology.

# Defines the schema of the document that a Record maps to. 
# Includes definitions of which fields are binary, or need to be indexed
has schema => (
    is => 'ro',
    isa => 'Obj',
    lazy => 1,
    default => sub { },
);

# The location on disk of the document store.
has index => (
    is => 'rw',
    isa => 'Str',
);

# The document store indexing object, used for loading documents into the store
has indexer => (
    is => 'ro',
    isa=> 'Obj',
    lazy => 1,
    default => sub { },
);

# Explicitly tell the document store to keep a document.
sub store_record {
    
}

# Call for the document store to commit any documents. Called to ensure transactional behaviour.
sub commit {
    
}

sub compress_json {
  my ($self, $ref) = @_;
  my $json = JSON::XS->new->allow_blessed->encode($ref);
  my $compressed;
  open my $fh, ">:gzip", \$compressed or Bio::EnsEMBL::Mongoose::IOException->throw("Cannot compress! $!");
  print $fh $json;
  close $fh;
  my $encoded = encode_base64($compressed);
  $encoded =~ s/\n//g;
  return $encoded;
}

sub decompress_json {
  my ($self, $base64_gz_contents) = @_;
  my $gz_contents = decode_base64($base64_gz_contents);
  local $/ = undef;
  open my $fh, "<:gzip", \$gz_contents or Bio::EnsEMBL::Mongoose::IOException->throw($!);
  my $uncompressed = <$fh>;
  close $fh;
  my $perl_hash = decode_json($uncompressed);
  return $perl_hash;
}

sub compress_sereal {
    my ($self, $content) = @_;
    my $encoded = encode_sereal($content, {snappy => 0});
    # Snappy isn't good enough for sequence, gzip the encoded version instead.
    my $compressed;
    open my $fh, ">:gzip", \$compressed or Bio::EnsEMBL::Mongoose::IOException->throw($!);
    print $fh $encoded;
    close $fh;
    return $compressed;
}

sub decompress_sereal {
    my ($self, $content) = @_; 
    local $/ = undef;
    open my $fh, "<:gzip", \$content or Bio::EnsEMBL::Mongoose::IOException->throw($!);
    my $unpacked = <$fh>;
    my $decoded = decode_sereal($unpacked);
    close $fh;
    return $decoded;
}
1;