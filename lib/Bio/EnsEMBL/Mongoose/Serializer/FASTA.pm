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
    isa => 'CodeRef',
    is => 'rw',
    lazy => 1,
    default => sub {
        return sub {
            my $self = shift;
            my $record = shift;
            my $accession = $record->primary_accession;
            unless ($accession) {
                $accession = $record->accessions->shift;
            }
            my $handle = $self->handle;
            printf $handle "> %s %s %s %s\n", $accession, $record->taxon_id, $record->evidence_level, ""; 
        }
    }
);

has handle => (
    isa => 'Ref',
    is => 'ro',
    default => sub {
        # no file handle, let the handle point to a copy of STDOUT instead
        my $handle;
        warn "Making handle";
        open $handle, ">&STDOUT";
        return $handle;
    } 
);

sub DEMOLISH {
    my $self = shift;
    close $self->handle;
}

sub print_record {
    my $self = shift;
    my $record = shift;
    my $handle = $self->handle;
    
    my $function = $self->header_function;
    &$function($self,$record);
    
    my $seq = $record->sequence;
    my $width = $self->linewidth;
    $seq =~ s/(.{1,$width})/$1\n/g;
    print $handle $seq or die "Error writing to file handle: $!";
}


1;