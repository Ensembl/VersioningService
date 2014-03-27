use XML::LibXML;
use XML::LibXML::SAX;
use PerlIO::gzip;
use XML::SAX::ParserFactory;



my $source = "/mysql/mongoose/data/uniprot_trembl.xml.gz";
$source = "$ENV{MONGOOSE}/t/data/braf.xml";
$source = "/Users/ktaylor/projects/data/uniprot_sprot.xml.gz";

my $fh;
open $fh,'<:gzip(autopop)', $source or die "Where is my XML? $source";

my $parser = XML::SAX::ParserFactory->parser(Handler => ADHDHandler->new());
$parser->parse_file($fh);

close $fh;


package ADHDHandler;

use base qw/XML::LibXML::SAX/;
use Data::Dump::Color qw/dump/;

our $texting = 0;
our $depth = 0;

sub start_element {
    my ($self, $el) = @_;
    $depth++;
    if ($depth == 3 && $el->{LocalName} eq "name") {
#        print dump($el)."\n";
#        print $el->{Value}."\n\n\n";
#        print $el->{Name}."\n";
        $texting = 1;
    }
}

sub end_element {
    my ($self, $el) = @_;
    $depth--;
}

sub characters {
    my ($self, $chars) = @_;
    if ($texting) {
        print $chars->{Data}."\n";
        $texting = 0;
    } 
}

1;