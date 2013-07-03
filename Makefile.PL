use ExtUtils::MakeMaker;

# Further possible options defined at: https://metacpan.org/module/ExtUtils::MakeMaker

WriteMakefile (
    NAME    => 'Bio::EnsEMBL::Mongoose',
    ABSTACT => 'A versioning service for handling data files',
    AUTHOR => ['Ensembl project, dev@ensembl.org'],
    BUILD_REQUIRES => {
        "Moose" => 0,
        
    },
    LICENSE => "bsd",
    
);