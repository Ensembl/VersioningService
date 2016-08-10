# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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