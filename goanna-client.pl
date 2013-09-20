#!/usr/local2/perl-5.16.2/bin/perl

use Modern::Perl '2010'; 
use HTTP::Request::Common;
use Furl;
use Getopt::Long::Descriptive;

## Command-line options
my ($opt, $usage) = describe_options(
    'goannashim %o <some-arg>',
    [ 'program|p=s', "BLAST program to use for searching", { 
        required => 1,
        callbacks => {
            #'smaller than a breadbox' => sub { shift() < $breadbox },
            'must be either blastp or blastx' => sub { $_[0] eq 'blastp' || $_[0] eq 'blastx' },
        },
    }],
    [ 'email|e=s', "submitter\'s email address to recieve notifications", { required => 1 } ],
    [ 'type|t=s', "type of input file: one of \'fasta\' or \'acc\'", { 
        required => 1,
        callbacks => {
            'must be one of' => sub {
                $_[0] eq 'fasta' || $_[0] eq 'acc' 
            },
        },
    }],
    [ 'file|f=s', "file name of sequence data to upload", { required => 1 } ],  # equals ID_LIST; only 1
    [ 'databases|D=s', "Databases to query", {  ## TODO delimit with whitespace or keep commas?
        required => 1,
        callbacks => {
            'must be one to three of' => sub {
                ## future proof! could use smartmatch '~~' here, 
                #  but Perl >= 5.18.x deprecates it!                
                ## Validate a list in a list...
                my $occurrences = 0;

                my @valid_databases = qw/AgBase uniprot_sprot uniprot_swisstrembl uniprot_trembl 9913 9031 9615 9823 rice bird fish fungi mammal mouse_chick_human nematode plant/;
                my @databases = split /,/, $_[0];
                foreach my $database (@databases) {            
                    $occurrences++ if scalar( grep { $_ eq $database } @valid_databases );
                }
                # ensure between 1 and 3 occurrences AND that all passed databases are valid!
                $occurrences >= 1 && $occurrences <= 3 && $occurrences == $#databases + 1;  # + 1 since indices start at 0
            },
        },
    }],
    [ 'expect|x=i', "", { default => 10, required => 0 } ],
    [ 'no_iea', ""],  # a flag
    [ 'low_complexity|l', ""],  # a flag
    [ 'descriptions|d=i', "", { default => 3 } ],
    [ 'alignments|a=i', "", { default => 3 } ],
    [ 'word_size|w=i', "", { default => 3 } ],
    [ 'matrix|m=s', "", { 
        default => 'BLOSUM62',
        callbacks => {
            'must be one of' => sub {
                scalar( grep { $_ eq $_[0] } qw/PAM30 PAM70 BLOSUM80 BLOSUM62 BLOSUM45/)
            },
        },
    }],
    [ 'gap_costs|g=s', "", {
        default => 'Existence: 11 Extension: 1',
        callbacks => {
            'must be one of' => sub {
                scalar( grep { $_ eq $_[0] } ("Existence: 9 Extension: 2", "Existence: 8 Extension: 2", "Existence: 7 Extension: 2", "Existence: 11 Extension: 1", "Existence: 12 Extension: 1", "Existence: 10 Extension: 1"))
            },
        },
    }],
    [ 'bypass_prg_check=i', "", { default => 0 } ],
    [ 'error=i', "", { default => 0 } ],
    ## TODO better to make evidence codes a comma-delimited list for option: '--codes=EXP,IBA'
    [ 'EXP', "Inferred from Experiment"],
    [ 'IBA', "Inferred from Biological aspect of Ancestor"],
    [ 'IBD', "Inferred from Biological aspect of Descendant"],
    [ 'IC', "Inferred by Curator"],
    [ 'IDA', "Inferred from Direct Assay"],
    [ 'IEA', "Inferred from Electronic Annotation"],
    [ 'IEP', "Inferred from Expression Pattern"],
    [ 'IGC', "Inferred from Genomic Context"],
    [ 'IGI', "Inferred from Genetic Interaction"],
    [ 'IKR', "Inferred from Key Residues"],
    [ 'IMP', "Inferred from Mutant Phenotype"],
    [ 'IPI', "Inferred from Physical Interaction"],
    [ 'IRD', "Inferred from Rapid Divergence"],
    [ 'ISA', "Inferred from Sequence Alignment"],
    [ 'ISM', "Inferred from Sequence Model"],
    [ 'ISO', "Inferred from Sequence Orthology"],
    [ 'ISS', "Inferred from Sequence or Structural Similarity"],
    [ 'NAS', "Non-traceable Author Statement"],
    [ 'ND', "No biological Data available"],
    [ 'NR', "Not Recorded"],
    [ 'RCA', "Inferred from Reviewed Computational Analysis"],
    [ 'TAS', "Traceable Author Statement"],
    [ 'help',       "print usage message and exit" ],
);

# Construct global (!) HTTP requestor
my $furl = Furl->new(
    agent   => 'GoAnna-Client-Script/1.0',
    timeout => 10,
);

my $data = format_options($opt);

# $submission_content contains the job_id, which we need to retrieve the zip file...
my $submission_content = submit_job($furl, $data); 
my $results_status = save_results($submission_content);
die;

=head2 Format Options

Format the data from command line options into an HTTP POST format.
=cut
sub format_options {
    my $opt = shift;
    
    ## Create POST data...
    my $post_data = [
        'PROGRAM' => $opt->program,
        'EMAIL' => $opt->email,
        'file_type' => $opt->type,
        'MATRIX_NAME' => $opt->matrix,
        'EXPECT' => $opt->expect,
        'FILTER' => ( $opt->can('low_complexity') && $opt->low_complexity ) ? "1" : "",
        'no_iea' => $opt->no_iea,
        'WORD_SIZE' => $opt->word_size,
        'DESCRIPTIONS' => $opt->descriptions,
        'ALIGNMENTS' => $opt->alignments,
        'GAP_COSTS' => $opt->gap_costs,
        'IDLIST' => [$opt->file],
        'error' => $opt->error,
        'bypass_prg_check' => $opt->bypass_prg_check,
        ## @TODO: ought to wrap $opt-> in eval() per brian d foy: if( my $ref = eval { $obj->can( $method ) } )
        'EXP' => ( $opt->can('exp') && $opt->exp ) ? "EXP" : "",
        'IBA' => ( $opt->can('iba') && $opt->iba ) ? "IBA" : "",
        'IBD' => ( $opt->can('ibd') && $opt->ibd ) ? "IBD" : "",
        'IC' =>  ( $opt->can('ic') && $opt->ic ) ? "IC" : "",
        'IDA' => ( $opt->can('ida') && $opt->ida ) ? "IDA" : "", 
        'IEA' => ( $opt->can('iea') && $opt->ida ) ? "IEA" : "",
        'IEP' => ( $opt->can('iep') && $opt->iep ) ? "IEP" : "",
        'IGC' => ( $opt->can('igc') && $opt->igc ) ? "IGC" : "",
        'IGI' => ( $opt->can('igi') && $opt->igi ) ? "IGI" : "",
        'IKR' => ( $opt->can('ikr') && $opt->ikr ) ? "IKR" : "",
        'IMP' => ( $opt->can('imp') && $opt->imp ) ? "IMP" : "",
        'IPI' => ( $opt->can('ipi') && $opt->ipi ) ? "IPI" : "",
        'IRD' => ( $opt->can('ird') && $opt->ird ) ? "IRD" : "",
        'ISA' => ( $opt->can('isa') && $opt->isa ) ? "ISA" : "",
        'ISM' => ( $opt->can('ism') && $opt->ism ) ? "ISM" : "",
        'ISO' => ( $opt->can('iso') && $opt->iso ) ? "ISO" : "",
        'ISS' => ( $opt->can('iss') && $opt->iss ) ? "ISS" : "",
        'NAS' => ( $opt->can('nas') && $opt->nas ) ? "NAS" : "",
        'ND' =>  ( $opt->can('nd') && $opt->nd ) ? "ND" : "",
        'NR' =>  ( $opt->can('nr') && $opt->nr ) ? "NR" : "",
        'RCA' => ( $opt->can('rca') && $opt->rca ) ? "RCA" : "",
        'TAS' => ( $opt->can('tas') && $opt->tas ) ? "TAS" : "",
        'search_field' => 'Select ID',
        'submit' => 'BLAST'
    ];

    ## Add multiple search databases to POST data
    my @databases = split /,/, $opt->databases;
    foreach my $database (@databases) {            
        push @{$post_data}, 'DATABASE', $database;
    }
    return $post_data;
}


=head2

Submit the job to the GoAnna Server via HTTP POST
=cut
sub submit_job {
    # get options from the formatter
    my $furl = shift;
    my $post_data = shift;
    #my ($furl, $post_data) = @_;
    
    # POST the data from the command line
    my $req = POST 'http://agbase.hpc.msstate.edu/cgi-bin/tools/GOanna.cgi',
        Content_Type => 'form-data', 
        Content => $post_data;

    my $res = $furl->request($req);
    die $res->status_line unless $res->is_success;
    return $res->content;
}


=head2


Fetch the resulting zip file of the analysis results and save it
=cut
sub save_results {
    my $submission = shift;
    my $save_to_path = shift // '.';    

    # Get the job id and capture the match
    $submission =~ /job_id\:\s(\S{6}\S{10})/i;
    my $job_id = $1;    
    
    my $result_zip = $furl->get("http://www.agbase.msstate.edu/tmp/GOAL/" . $job_id .  '.zip');
    
    my $maxwait = 1200;
    my $initwait = 10;
    my $totalwait = 0;
    if (defined $job_id) {
        until ( $result_zip->is_success ) {
            print "Error downloading file: " . $job_id . ".zip:" . $result_zip->status . "\n";
            
            ## Incremental backout; let's do a fibonacci backout instead!
            print "Trying again in $initwait seconds\n";
            sleep($initwait);
            $initwait = $initwait * 1.2;
            if ($initwait > $maxwait) {
                $initwait=$maxwait;
            }
            $totalwait=$totalwait + $initwait;
            
            $result_zip = $furl->get("http://www.agbase.msstate.edu/tmp/GOAL/" . $job_id .  '.zip');
            open(my $ZIP, '>', $job_id . '.zip') or die "cannot write > " .  $job_id . '.zip' . " [$!]";
            print $ZIP $result_zip->content;

            if ($totalwait > 36000) {
                print "Maximum wait time exceeded; either GOanna is down or the submission will never finish.";
                exit;
            }
        }

        if ( $result_zip->is_success ) {
            print "The GOanna file downloaded correctly\nIts name is " . $job_id . ".zip\n";
            exit;
        }
    } else {
        print "The submission failed, likely because of bad parameters\n";
        exit;
    }
}
