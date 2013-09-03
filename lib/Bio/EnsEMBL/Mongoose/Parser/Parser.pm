package Bio::EnsEMBL::Mongoose::Parser::Parser;
use Moose::Role;

use PerlIO::gzip;


has 'source_file' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'source_handle' => (
    isa => 'GlobRef',
    is => 'rw',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $fh;
        open $fh, "<:gzip(autopop)", $self->source_file;
        return $fh;
    }
);


sub read_record {
    
}

1;