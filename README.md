[![Build Status](https://travis-ci.org/Ensembl/VersioningService.png?branch=master)][travis]
[![Coverage Status](https://coveralls.io/repos/Ensembl/VersioningService/badge.png)][coveralls]

[travis]: https://travis-ci.org/Ensembl/VersioningService
[coveralls]: https://coveralls.io/r/Ensembl/VersioningService

# Versioning Service
Service for downloading and consuming external data integrated into Ensembl releases.

Currently this repository consists of several components, the versioning service and a pipeline for transforming external data into more useful formats

## Versioning Service component

This service (and Perl API) is intended to allow Ensembl to work with one copy of a given external data resource, and to have a legacy of previous versions to fall back to in the event of format changes or corruption. Its prime customer will be the Xref pipeline, whose multiple runs require frequent access to the same data over and over.

A Broker object provides a single point of access to all copies of downloaded resources, as well as any indexes built upon them. The number of likely interactions between client and data are few at this time, hence a single object is sufficient to look up and retrieve the data needed. The Broker does not act as a conduit for data, it dishes out filesystem locations instead, for current data or for managing new data.

The Versioning Service is built on a combination of Moose and DBIx::Class, and requires a modest SQL backend to operate.

## Versioning pipeline

Regular running of the pipeline allows the Versioning service to keep up to date with external data providers. The pipeline inspects all known sources for signs of change, before downloading new copies of the data where appropriate. In this way Ensembl is able to use the latest releases of external data whenever needed.

The Versioning pipeline uses Ensembl eHive, and operates via cron (see also /scripts/cron_update)

## "Mongoose" indexing and access

Bioinformatics file formats are too numerous and diverse. For general use of external data, it is helpful to index the various data sets into an adaptable document-store. Lucene-style querying can then be used to do quick lookups of commonly interesting data. This includes a feature that mimicks some of the capabilities of mfetch, such as creating a subset of FASTA files limited to a taxonomic group.

Mongoose is built with more Moose, Lucy and JSON. The Lucy indexer has been designed to be modular, and should then be interchangeable with most NoSQL solutions, or an RDBMS with additional work.

The only persistent service is the SQL database required for the Broker to manage its file collection. Multiple clients can individually access the same files or index through the API. Should performance become a problem, temporary copies of the archived downloads can be created to help distribute IO.

# Xref Pipeline

Xrefs are computed in RDF space, that is the indexed records stored by the "Mongoose" component above are converted to an RDF graph, which then forms the basis for the Xref pipeline. See Bio::EnsEMBL::Versioning::Pipeline::PipeConfig::Xref_pipeline_conf

As part of this conversion process, sequences are aligned, coordinates are compared, checksums are checked and so on. 

The alignment process is run on FASTA of cDNA extracted from indexes, as well as from the Ensembl core DB for a specific species. Exonerate is used with an automatic filter threshold on its results to remove poor alignments. That threshold is dependent on the data involved, and can be tuned per-species and per data type if necessary.

The checksum comparison is made by computing MD5 checksums for all gene, transcript and translation sequences in Ensembl. This list is then used in the context of checksums stored in specific source indexes.

Coordinate comparison is done with specific reference to RefSeq, and where on the genome they place their features. Ensembl Genebuild map these coordinates into an Ensembl database, which are then used to find alternate pairings to converntional alignment. The sequence differnces between the approaches of Ensembl and RefSeq ensure that alignments alone can never be good enough, in the main because of differing approaches to UTRs. Coordinate matches are considered the most authoritative connection, with alignments and checksums used where no positional match is possible.

# Reasoning/inference/correction

Once all RDF is generated, we can start to make choices about which pairings are preferred, and store that choice in an Ensembl core DB. This process is not finalised, and is subject to extensive revision.