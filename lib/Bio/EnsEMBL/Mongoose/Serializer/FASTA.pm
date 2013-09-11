package Bio::EnsEMBL::Mongoose::Serializer::FASTA;

use Moose;

has linewidth => (
    isa => 'Int',
    is => 'ro',
    required => 1,
    default => 60,
);

# No chunk size, only writing smaller things

has header_function => (
    usa => 'CodeRef',
    is => 'rw',
    required => 1,
    default => \sub {
        my $self = shift;
        my $record = shift;
        
    }
);

has handle => (
    isa => 'Ref',
    is => 'ro',
    default => sub {
        # no file handle, let the handle point to a copy of STDOUT instead
        my $handle;
        open $handle, ">&STDOUT";
        return $handle;
    },
    
);

sub print_record {
    my $self = shift;
    my $record = shift;
    my $handle = $self->handle;
    
    my $function = $self->header_function;
    &$function($record);
    
    my $seq = $record->sequence;
    my $width = $self->linewidth;
    $seq =~ s/(.{1,$width})/$1\n/g;
    print $handle $seq or die "Error writing to file handle: $!";
}


1;