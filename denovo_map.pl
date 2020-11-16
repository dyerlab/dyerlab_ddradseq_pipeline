#!/usr/bin/env perl
#
# Copyright 2010-2020, Julian Catchen <jcatchen@illinois.edu>
#
# This file is part of Stacks.
#
# Stacks is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Stacks is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Stacks.  If not, see <http://www.gnu.org/licenses/>.
#

use strict;
use POSIX;
use File::Temp qw/ mktemp /;
use File::Spec;
use constant stacks_version => "_VERSION_";

use constant true  => 1;
use constant false => 0;

my $dry_run      = false;
my $exe_path     = "/gpfs_fs/hohensteinta/bin/stacks-2.54";
my $out_path     = "";
my $popmap_path  = "";
my $sample_path  = "";
my $db           = "";
my $min_cov      = 0;
my $sample_id    = 1;
my $gzip         = false;
my $paired       = false;
my $resume       = false;
my $force_reexe  = false;
my $genetic_map  = false;
my $time         = "";

my @parents;
my @progeny;
my @samples;

my (@_ustacks, @_cstacks, @_sstacks, @_tsv2bam, @_gstacks, @_populations);

my $cmd_str = $0 . " " . join(" ", @ARGV);

parse_command_line();

#
# Check for the existence of the necessary pipeline programs
#
foreach my $prog ("ustacks", "cstacks", "sstacks", "tsv2bam", "gstacks", "populations") {
    die "Unable to find '" . $exe_path . $prog . "'.\n" if (!-e $exe_path . $prog);
}

my ($log, $log_fh, $sample);

my (@sample_list, %pop_ids, %pops, %grp_ids, %grps, %sample_ids);

parse_population_map(\@sample_list, \%pop_ids, \%pops, \%grp_ids, \%grps, \$genetic_map);

initialize_samples(\@parents, \@progeny, \@samples, \@sample_list, \%pop_ids, \%grp_ids);

#
# Open the log file
#
$log = "$out_path/denovo_map.log";

#
# If we are resuming, check if the log exists and append to it.
#
if ($resume == true) {
    open($log_fh, ">>$log") or die("Unable to open log file '$log'; $!\n");

    print $log_fh
        "\n",
        "denovo_map.pl version ", stacks_version, " resuming at ", strftime("%Y-%m-%d %H:%M:%S", (localtime(time))), "\n",
        $cmd_str, "\n";

} else {
    open($log_fh, ">$log") or die("Unable to open log file '$log'; $!\n");

    print $log_fh
        "denovo_map.pl version ", stacks_version, " started at ", strftime("%Y-%m-%d %H:%M:%S", (localtime(time))), "\n",
        $cmd_str, "\n";
}

execute_stacks($log_fh, $sample_id, \@parents, \@progeny, \@samples, \%sample_ids);

print $log_fh "\ndenovo_map.pl completed at ", strftime("%Y-%m-%d %H:%M:%S", (localtime(time))), "\n";
close($log_fh);


sub check_return_value {
    # $? is a 16 bit int. Exit code is given by `$? & 255` if the process was
    # terminated by a signal, and by `$? >> 8` if it exited normally.
    my ($rv, $log_fh) = @_;
    if ($rv != 0) {
        my $code = ($rv >> 8) & 127;
        if ($rv & 255 || ($rv >> 8) > 127) {
            $code += 128;
        }
        my $msg = "\ndenovo_map.pl: Aborted because the last command failed ($code";
        if ($code == 129 || $code == 130 || $code == 131) {
            $msg .= "/interrupted";
        } elsif ($code == 137 || $code == 143) {
            $msg .= "/killed";
        } elsif ($code == 134) {
            $msg .= "/SIGABRT";
        } elsif ($code == 139) {
            $msg .= "/segmentation fault";
        }
        $msg .= ")";
        print $log_fh ($msg . ".\n");
        print STDERR ($msg . "; see log file.\n");
        exit 1;
    }
}

sub execute_stacks {
    my ($log_fh, $sample_id, $parents, $progeny, $samples, $sample_ids) = @_;

    my (@results, @depths_of_cov, @prev_completed_ustacks);
    my ($pop_cnt, $sample, $num_files, $i, $cmd, $pipe_fh);

    my $minc  = $min_cov  > 0 ? " -m $min_cov"  : "";

    $i         = 1;
    $num_files = scalar(@{$parents}) + scalar(@{$progeny}) + scalar(@{$samples});

    #
    # Assemble RAD loci in each individual.
    #
    print STDERR "Indentifying unique stacks...\n";
    print $log_fh "\nustacks\n==========\n";
    foreach $sample (@{$parents}, @{$progeny}, @{$samples}) {

        print $log_fh "\nSample $i of $num_files '$sample->{'file'}'\n----------\n";

        if (scalar(keys %{$sample_ids}) > 0) {
            $sample_id = $sample_ids->{$sample->{'file'}};
        }

        #
        # If resuming the pipeline, test if this sample already has been processed.
        #
        if ($resume == true and ustacks_sample_exists($sample, $out_path) == true) {
            push(@prev_completed_ustacks, $sample);
            print STDERR  "  Sample '$sample->{'file'}' already exists, will use existing data.\n";
            print $log_fh "Sample '$sample->{'file'}' already exists, will use existing data.\n";
            $i++;
            $sample_id++;
            next;
        }

        $cmd = $exe_path . "ustacks -t $sample->{'fmt'} -f $sample->{'path'} -o $out_path -i $sample_id" . $minc;

        if ($sample->{'path'} !~ /$sample->{'file'}.$sample->{'suffix'}$/) {
            # Guessing the sample name from the input path won't work.
            $cmd .= " --name " . $sample->{'file'};
        }
        foreach (@_ustacks) {
            $cmd .= " " . $_;
        }
        print STDERR  "  $cmd\n";
        print $log_fh "$cmd\n";

        if ($dry_run == false) {
            open($pipe_fh, "$time $cmd 2>&1 |");
            @results = ();
            while (<$pipe_fh>) {
                print $log_fh $_;
                push(@results, $_);
            }
            close($pipe_fh);
            check_return_value($?, $log_fh);

            #
            # Pull the depth of coverage from ustacks.
            #
            my $depthline = (grep(/^Final coverage/, @results))[0];
            my ($depth) = ($depthline =~ /mean=([^;]+)/);
            push(@depths_of_cov, [$sample->{'file'}, $depth]);
        }

        $i++;
        $sample_id++;
    }

    write_depths_of_cov(\@depths_of_cov, $log_fh);
    print STDERR "\n";

    #
    # Generate catalog of RAD loci.
    #
    print STDERR "Generating catalog...\n";
    print $log_fh "\ncstacks\n==========\n";

    
    #
    # If a genetic map was specified (based on the population map), only place
    # samples that are 'parent' into the catalog.
    #
    if ($genetic_map == true) {
        my @params = ();
        while (@_cstacks) {
            my $param = pop(@_cstacks);
            next if (substr($param, 0, 2) eq "-M");
            push(@params, $param);
        }
        push(@_cstacks, @params);

        foreach $sample (@{$parents}) {
            push(@_cstacks, "-s " . $out_path . "/" . $sample->{'file'});
        }
        push(@_cstacks, "-o $out_path");

    } else {
        push(@_cstacks, "-P $out_path");
    }

    #
    # If the pipeline is in --resume mode, check if all ustacks samples existed previously and
    # if the catalog already exists.
    #
    if ($resume == true and catalog_exists(\@prev_completed_ustacks, $parents, $progeny, $samples, $out_path) == true) {
        print STDERR  "  Catalog already exists, will use existing data.\n\n";
        print $log_fh "Catalog already exists, will use existing data.\n\n";

    } else {
        #
        # If --resume is enabled and we ended up re-executing cstacks, force everything downstream to re-execute.
        #
        $force_reexe = true if ($resume == true);
        
        $cmd = $exe_path . "cstacks " . join(" ", @_cstacks);
        print STDERR  "  $cmd\n\n";
        print $log_fh "$cmd\n\n";

        if ($dry_run == false) {
            open($pipe_fh, "$time $cmd 2>&1 |");
            while (<$pipe_fh>) {
                print $log_fh $_;
                if ($_ =~ /failed/i) { print STDERR "Catalog construction failed.\n"; exit(1); }
            }
            close($pipe_fh);
            check_return_value($?, $log_fh);
        }
    }

    #
    # Match parents, progeny, or samples to the catalog.
    #
    print STDERR "Matching samples to the catalog...\n";
    print $log_fh "\nsstacks\n==========\n";

    if ($resume == true and sstacks_samples_exist($parents, $progeny, $samples, $out_path) == true) {
        print STDERR  "  sstacks matches already exist, will use existing data.\n\n";
        print $log_fh "sstacks matches already exist, will use existing data.\n\n";

    } else {
        #
        # If --resume is enabled and we ended up re-executing sstacks, force everything downstream to re-execute.
        #
        $force_reexe = true if ($resume == true);
        
        $cmd      = $exe_path . "sstacks -P $out_path " . join(" ", @_sstacks);
        print STDERR  "  $cmd\n\n";
        print $log_fh "$cmd\n\n";

        if ($dry_run == false) {
            open($pipe_fh, "$time $cmd 2>&1 |");
            while (<$pipe_fh>) {
                print $log_fh $_;
            }
            close($pipe_fh);
            check_return_value($?, $log_fh);
        }
    }

    #
    # Sort the reads according by catalog locus / run tsv2bam.
    #
    print STDERR "Sorting reads by RAD locus...\n";
    print $log_fh "\ntsv2bam\n==========\n";

    if ($resume == true and tsv2bam_samples_exist($parents, $progeny, $samples, $out_path) == true) {
        print STDERR  "  tsv2bam samples already exist, will use existing data.\n\n";
        print $log_fh "tsv2bam samples already exist, will use existing data.\n\n";

    } else {
        #
        # If --resume is enabled and we ended up re-executing tsv2bam, force everything downstream to re-execute.
        #
        $force_reexe = true if ($resume == true);
        
        my $file_paths = "";
        if (length($popmap_path) == 0) {
            foreach $sample (@{$parents}, @{$progeny}, @{$samples}) {
                $file_paths .= " -s $sample->{'file'}";
            }
        }

        $cmd = $exe_path . "tsv2bam -P $out_path $file_paths " . join(" ", @_tsv2bam);
        print STDERR  "  $cmd\n\n";
        print $log_fh "$cmd\n\n";

        if (!$dry_run) {
            open($pipe_fh, "$time $cmd 2>&1 |");
            while (<$pipe_fh>) {
                print $log_fh $_;
            }
            close($pipe_fh);
            check_return_value($?, $log_fh);
        }
    }

    #
    # Call genotypes / run gstacks.
    #
    print STDERR "Calling variants, genotypes and haplotypes...\n";
    print $log_fh "\ngstacks\n==========\n";

    if ($resume == true and gstacks_output_exists($out_path) == true) {
        print STDERR  "  gstacks catalog already exists, will use existing data.\n\n";
        print $log_fh "gstacks catalog already exists, will use existing data.\n\n";

    } else {
        $cmd = $exe_path . "gstacks -P $out_path " . join(" ", @_gstacks);
        print STDERR  "  $cmd\n\n";
        print $log_fh "$cmd\n\n";

        if (!$dry_run) {
            open($pipe_fh, "$time $cmd 2>&1 |");
            while (<$pipe_fh>) {
                print $log_fh $_;
            }
            close($pipe_fh);
            check_return_value($?, $log_fh);
        }
    }

    printf(STDERR "Calculating population-level summary statistics\n");
    print $log_fh "\npopulations\n==========\n";

    $cmd = $exe_path . "populations" . " -P $out_path " . join(" ", @_populations);
    print STDERR  "  $cmd\n\n";
    print $log_fh "$cmd\n\n";

    if ($dry_run == 0) {
        open($pipe_fh, "$time $cmd 2>&1 |");
        while (<$pipe_fh>) {
            print $log_fh $_;
        }
        close($pipe_fh);
        check_return_value($?, $log_fh);
    }

    print STDERR  "denovo_map.pl is done.\n";
    print $log_fh "denovo_map.pl is done.\n";
}

sub ustacks_sample_exists {
    my ($sample, $out_path) = @_;

    my $path = $out_path . "/" . $sample->{'file'} . ".alleles.tsv.gz";

    # Check the file exists and is not empty.
    return false if (!-e $path || -z _);

    my $fh;
    open($fh, "gunzip -c $path | tail -n 1 |") or die("Unable to read ustacks file, '$path'\n");
    my $line = <$fh>;
    close($fh);

    chomp $line;

    return true if ($line =~ /^# ustacks completed/);

    return false;
}

sub catalog_exists {
    my ($prev_completed_ustacks, $parents, $progeny, $samples, $out_path) = @_;

    return false if ($force_reexe == true);

    my $sample_cnt = 0;
    
    if ($genetic_map == true) {
        $sample_cnt = scalar(@{$parents}) + scalar(@{$progeny});
    } else {
        $sample_cnt = scalar(@{$samples});
    }

    #
    # If all ustacks samples have been processed, check if the catalog was completed.
    #
    if ($sample_cnt == scalar(@{$prev_completed_ustacks})) {
        
        my $path = $out_path . "/catalog.tags.tsv.gz";

        # Check the file exists and is not empty.
        return false if (!-e $path || -z _);

        my $path = $out_path . "/catalog.snps.tsv.gz";
        return false if (!-e $path || -z _);

        my $path = $out_path . "/catalog.alleles.tsv.gz";
        return false if (!-e $path || -z _);

        my $fh;
        open($fh, "gunzip -c $path | tail -n 1 |") or die("Unable to read catalog file, '$path'\n");
        my $line = <$fh>;
        close($fh);

        chomp $line;

        return true if ($line =~ /^# cstacks completed/);
    }
    
    return false;
}

sub sstacks_samples_exist {
    my ($parents, $progeny, $samples, $out_path) = @_;

    return false if ($force_reexe == true);

    my $sample_cnt    = scalar(@{$parents}) + scalar(@{$progeny}) + scalar(@{$samples});
    my $completed_cnt = 0;

    foreach $sample (@{$parents}, @{$progeny}, @{$samples}) {
        my $path = $out_path . "/" . $sample->{'file'} . ".matches.tsv.gz";

        # Check the file exists and is not empty.
        return false if (!-e $path || -z _);

        my $fh;
        open($fh, "gunzip -c $path | tail -n 1 |") or die("Unable to read sstacks file, '$path'\n");
        my $line = <$fh>;
        close($fh);

        chomp $line;

        $completed_cnt++ if ($line =~ /^# sstacks completed/);
    }

    if ($sample_cnt == $completed_cnt) {
        return true;
    }
    
    return false;
}

sub tsv2bam_samples_exist {
    my ($parents, $progeny, $samples, $out_path) = @_;

    return false if ($force_reexe == true);
    
    my $sample_cnt    = scalar(@{$parents}) + scalar(@{$progeny}) + scalar(@{$samples});
    my $completed_cnt = 0;

    foreach $sample (@{$parents}, @{$progeny}, @{$samples}) {
        my $path = $out_path . "/" . $sample->{'file'} . ".matches.bam";

        # Check the file exists and is not empty.
        $completed_cnt++ if (-e $path && !-z _);
    }

    if ($sample_cnt == $completed_cnt) {
        my $path = $out_path . "/tsv2bam.log";

        # Check the file exists and is not empty.
        return false if (!-e $path || -z _);

        my $fh;
        open($fh, "tail -n 1 $path |") or die("Unable to read tsv2bam logfile, '$path'\n");
        my $line = <$fh>;
        close($fh);

        chomp $line;

        return true if ($line =~ /^tsv2bam is done./);
    }

    return false;
}

sub gstacks_output_exists {
    my ($out_path) = @_;

    return false if ($force_reexe == true);

    my $path = $out_path . "/catalog.fa.gz";

    # Check the file exists and is not empty.
    return false if (!-e $path || -z _);

    $path = $out_path . "/catalog.calls";
    return false if (!-e $path || -z _);

    $path = $out_path . "/gstacks.log";

    return false if (!-e $path || -z _);

    my $fh;
    open($fh, "tail -n 1 $path |") or die("Unable to read tsv2bam logfile, '$path'\n");
    my $line = <$fh>;
    close($fh);

    chomp $line;

    return true if ($line =~ /^gstacks is done./);
    
    return false;
}

sub parse_population_map {
    my ($sample_list, $pop_ids, $pops, $grp_ids, $grps, $map) = @_;

    my ($fh, @parts, $line, $sample);

    return if (length($popmap_path) == 0);

    open($fh, "<$popmap_path") or die("Unable to open population map, '$popmap_path', $!\n");

    while ($line = <$fh>) {
        chomp $line;
        next if ($line =~ /^\s*#/);

        @parts = split(/\t/, $line);
        if (scalar(@parts) != 2 and scalar(@parts) != 3) {
            die("Unable to parse population map, '$popmap_path' (expected 2 or 3 columns, found " . scalar(@parts) . "); at line:\n$line\n");
        }

        foreach my $part (@parts) {
            $part =~ s/^\s*|\s*$//g;
        }

        push(@{$sample_list}, $parts[0]);
        $pop_ids->{$parts[0]} = $parts[1];
        $pops->{$parts[1]}++;
        if (scalar(@parts) > 2) {
            $grp_ids->{$parts[0]} = $parts[2];
            $grps->{$parts[2]}++;
        }
    }

    if (scalar(keys %{$grps}) == 0) {
        $grps->{"1"}++;

        foreach $sample (@{$sample_list}) {
            $grp_ids->{$sample} = "1";
        }
    }

    print STDERR "Parsed population map: ", scalar(@{$sample_list}), " files in ", scalar(keys %{$pops});
    scalar(keys %{$pops}) == 1 ?  print STDERR " population" : print STDERR " populations";
    print STDERR " and ", scalar(keys %{$grps});
    scalar(keys %{$grps}) == 1 ? print STDERR " group.\n" : print STDERR " groups.\n";

    #
    # Test for a genetic map.
    #
    my @k = keys %{$pops};
    if (scalar(@k) == 2) {
        if ( ($k[0] eq "parent"  && $k[1] eq "progeny") ||
             ($k[0] eq "progeny" && $k[1] eq "parent") ) {
            print STDERR "Genetic map detected from population map, only 'parent' samples will be loaded into the catalog.\n";
            $$map = true;
        }
    }

    close($fh);
}

sub initialize_samples {
    my ($parents, $progeny, $samples, $sample_list, $pop_ids, $grp_ids) = @_;

    if (scalar(@{$sample_list}) > 0 && scalar(@{$samples}) == 0) {
        my @suffixes = ("fq",    "fastq", "fq.gz",   "fastq.gz", "fa",    "fasta", "fa.gz",   "fasta.gz");
        my @fmts     = ("fastq", "fastq", "gzfastq", "gzfastq",  "fasta", "fasta", "gzfasta", "gzfasta");

        #
        # Read the samples in from the population map.
        #
        my ($i, $extension, $extension_pe);
        my $first = true;
        foreach $sample (@{$sample_list}) {
            if ($first) {
                $first = false;
                my $found = false;
                for ($i = 0; $i < scalar(@suffixes); $i++) {
                    if (!$paired && -e $sample_path . $sample . "." . $suffixes[$i]) {
                        $found = true;
                        $extension = "." . $suffixes[$i];
                        last;
                    } elsif (!$paired && -e $sample_path . $sample . ".1." . $suffixes[$i]) {
                        $found = true;
                        $extension = ".1." . $suffixes[$i];
                        last;
                    } elsif (-e $sample_path . $sample . ".1." . $suffixes[$i]) {
                        $found = true;
                        $extension = ".1." . $suffixes[$i];
                        $extension_pe = ".2." . $suffixes[$i];
                        last;
                    }
                }
                if (!$found) {
                    print STDERR "Error: Failed to find the first reads file '$sample_path$sample(.1).(fq|fastq|fa|fasta)(.gz)'.\n";
                    exit 1;
                }
                if ($i == 2 || $i == 3 || $i == 6 || $i == 7) {
                    $gzip = true;
                }
            }

            my ($path, $path_pe);

            $path    = $sample_path . $sample . $extension;
            $path_pe = ($paired ? $sample_path . $sample . $extension_pe : "");

            die("Error: Failed to open single-end file '$path'.\n") if (! -e $path);
            die("Error: Failed to open paired-end file '$path_pe'.\n") if ($paired && ! -e $path_pe);
            die("Unable to find an entry for '" . $sample . "' in the population map, '$popmap_path'.\n") if (!defined($pop_ids->{$sample}));

            if ($genetic_map == true) {
                if ($pop_ids->{$sample} eq "parent") {
                    push(@{$parents}, {'path'    => $path,
                                       'file'    => $sample,
                                       'suffix'  => $suffixes[$i],
                                       'type'    => "parent",
                                       'fmt'     => $fmts[$i],
                                       'path_pe' => $path_pe});
                } else {
                    push(@{$progeny}, {'path'    => $path,
                                       'file'    => $sample,
                                       'suffix'  => $suffixes[$i],
                                       'type'    => "progeny",
                                       'fmt'     => $fmts[$i],
                                       'path_pe' => $path_pe});
                }
            } else {
                push(@{$samples}, {'path'    => $path,
                                   'file'    => $sample,
                                   'suffix'  => $suffixes[$i],
                                   'type'    => "sample",
                                   'fmt'     => $fmts[$i],
                                   'path_pe' => $path_pe});
            }
        }
    }

    #
    # If a population map was specified, make sure all samples in the list were found (and vice versa) and assign popualtion IDs.
    #
    my %sample_hash;

    foreach $sample (@{$samples}, @{$parents}, @{$progeny}) {
        $sample_hash{$sample->{'file'}}++;

        if (!defined($pop_ids->{$sample->{'file'}})) {
            die("Unable to find an entry for '" . $sample->{'file'} . "' in the population map, '$popmap_path'.\n");
        } else {
            $sample->{'pop_id'} = $pop_ids->{$sample->{'file'}};
        }
        if (!defined($grp_ids->{$sample->{'file'}})) {
            die("Unable to find an entry for '" . $sample->{'file'} . "' in the population map, '$popmap_path'.\n");
        } else {
            $sample->{'grp_id'} = $grp_ids->{$sample->{'file'}};
        }
    }

    foreach $sample (@{$sample_list}) {
        if (!defined($sample_hash{$sample})) {
            die("Unable to find a file corresponding to the population map entry '" . $sample . "' in the population map, '$popmap_path'.\n");
        }
    }

    #
    # Check that no duplicate files were specified.
    #
    my (%files, $file);
    foreach $file (@{$parents}, @{$progeny}, @{$samples}) {
        $files{$file}++;
    }
    foreach $file (keys %files) {
        if ($files{$file} > 1) {
            die("A duplicate file was specified which may create undefined results, '$file'\n");
        }
    }

    if (scalar(@{$samples}) > 0) {
        print STDERR "Found ", scalar(@{$samples}), " sample file(s).\n\n";
    } else {
        print STDERR
            "Found ", scalar(@{$parents}), " parental file(s).\n",
            "Found ", scalar(@{$progeny}), " progeny file(s).\n\n";
    }

    if ( scalar(@{$samples}) > 0 && (scalar(@{$parents}) > 0 || scalar(@{$progeny}) > 0) ) {
	die("Both samples and parents/progeny were specified either on the command line (-s/-r/-p) or within the population map. Only one of the other may be specified.\n");
    }
}

sub write_results {
    my ($results, $log_fh) = @_;

    my $line;

    foreach $line (@{$results}) {
        if ($line =~ /\r/) {
            $line =~ s/^.+\r(.*\n)$/\1/;
        }
        print $log_fh $line;
    }
}

sub write_depths_of_cov {
    my ($depths, $log_fh) = @_;

    print STDERR "\nDepths of Coverage for Processed Samples:\n";
    print $log_fh "\nDepths of Coverage for Processed Samples:\n";

    foreach $a (@{$depths}) {
        print STDERR  $a->[0], ": ", $a->[1], "x\n";
        print $log_fh $a->[0], ": ", $a->[1], "x\n";
    }
}

sub parse_command_line {
    my ($arg);

    my $ustacks_mismatch = -1;
    my $cstacks_mismatch = -1;

    while (@ARGV) {
        $_ = shift @ARGV;
        if    ($_ =~ /^-v$/ || $_ =~ /^--version$/) { version(); exit 1; }
        elsif ($_ =~ /^-h$/) { usage(); }
        elsif ($_ =~ /^-d$/ || $_ =~ /^--dry-run$/)  { $dry_run   = true; }
        elsif ($_ =~ /^-o$/ || $_ =~ /^--out-path$/) { $out_path  = shift @ARGV; }
        elsif ($_ =~ /^-e$/)        { $exe_path  = shift @ARGV; }
        elsif ($_ =~ /^-m$/)        { $min_cov     = shift @ARGV; }
        elsif ($_ =~ /^--resume$/)  { $resume      = true; }
        elsif ($_ =~ /^--paired$/)  { $paired      = true; }
        elsif ($_ =~ /^--samples$/) { $sample_path = shift @ARGV; }
        elsif ($_ =~ /^-O$/ || $_ =~ /^--popmap$/) {
            $popmap_path = shift @ARGV;
            push(@_cstacks,     "-M " . $popmap_path);
            push(@_sstacks,     "-M " . $popmap_path);
            push(@_tsv2bam,     "-M " . $popmap_path);
            push(@_gstacks,     "-M " . $popmap_path);
            push(@_populations, "-M " . $popmap_path);

        } elsif ($_ =~ /^-T$/ || $_ =~ /^--threads/) {
            $arg = shift @ARGV;
            push(@_ustacks, "-p " . $arg);
            push(@_cstacks, "-p " . $arg);
            push(@_sstacks, "-p " . $arg);
            push(@_tsv2bam, "-t " . $arg);
            push(@_gstacks, "-t " . $arg);
            push(@_populations, "-t " . $arg);

        } elsif ($_ =~ /^-M$/) {
            $ustacks_mismatch = shift(@ARGV);
            push(@_ustacks,   "-M " . $ustacks_mismatch);

        } elsif ($_ =~ /^-N$/) {
            push(@_ustacks,   "-N " . shift @ARGV);

        } elsif ($_ =~ /^-n$/) {
            $cstacks_mismatch = shift @ARGV;
            push(@_cstacks, "-n " . $cstacks_mismatch);

        } elsif ($_ =~ /^--rm-pcr-duplicates$/) {
            push(@_gstacks, "--rm-pcr-duplicates");

        } elsif ($_ =~ /^--var-alpha$/) {
            push(@_gstacks, "--var-alpha " . shift @ARGV);

        } elsif ($_ =~ /^--gt-alpha$/) {
            push(@_gstacks, "--gt-alpha " . shift @ARGV);

        } elsif ($_ =~ /^-r$/ || $_ =~ /^--min-samples-per-pop$/) {
            push(@_populations,   "--min-samples-per-pop " . shift @ARGV);

        } elsif ($_ =~ /^-p$/ || $_ =~ /^--min-populations$/) {
            push(@_populations,   "--min-populations " . shift @ARGV);

        } elsif ($_ =~ /^-X$/) {
            #
            # Pass an arbitrary command-line option to a pipeline program.
            #
            # Command line option must be of the form '-X "program:option"'
            #
            $arg = shift @ARGV;
            my ($prog, $opt) = ($arg =~ /^(\w+):(.+)$/);
            if ($prog eq "ustacks") {
            	push(@_ustacks, $opt);
            } elsif ($prog eq "cstacks") {
            	push(@_cstacks, $opt);
            } elsif ($prog eq "sstacks") {
            	push(@_sstacks, $opt);
            } elsif ($prog eq "tsv2bam") {
            	push(@_tsv2bam, $opt);
            } elsif ($prog eq "gstacks") {
            	push(@_gstacks, $opt);
            } elsif ($prog eq "populations") {
            	push(@_populations, $opt);
            } else {
            	print STDERR "Unknown pipeline program, '$arg'\n";
            	usage();
            }
        } elsif ($_ =~ /^--time-components$/) {
            $time = '/usr/bin/time';
            if (! -e $time) {
                die "Error: '$time': No such file or directory.\n";
            }
        } else {
            print STDERR "Unknown command line option: '$_'\n";
            usage();
        }
    }

    $exe_path = $exe_path . "/"          if (substr($exe_path, -1) ne "/");
    $out_path = substr($out_path, 0, -1) if (substr($out_path, -1) eq "/");

    if (length($popmap_path) == 0) {
        print STDERR "You must specify a population map that lists your sample names (--popmap).\n";
        usage();
    }

    if (length($sample_path) == 0) {
        print STDERR "You must specify the path to the directory containing the samples (--samples).\n";
        usage();
    }

    if (length($sample_path) > 0) {
        $sample_path .= "/" if (substr($sample_path, -1) ne "/");
    }

    if ($paired == true) {
        push(@_tsv2bam, "-R $sample_path");
    }

    #
    # By default, we want ustacks -M to equal cstacks -n.
    #
    if ($cstacks_mismatch == -1 && $ustacks_mismatch > 0) {
        push(@_cstacks, "-n " . $ustacks_mismatch);
    }
}

sub version {
    print STDERR "denovo_map.pl ", stacks_version, "\n";
}

sub usage {
    version();

    print STDERR <<EOQ;
denovo_map.pl --samples dir --popmap path --out-path dir [--paired [--rm-pcr-duplicates]] (assembly options) (filtering options) [-X prog:"opts" ...]

  Input/Output files:
    --samples: path to the directory containing the samples reads files.
    --popmap: path to a population map file (format is "<name> TAB <pop>", one sample per line).
    -o,--out-path: path to an output directory.

  General options:
    -X: additional options for specific pipeline components, e.g. -X "populations: --min-maf 0.05".
    -T, --threads: the number of threads/CPUs to use (default: 1).
    --dry-run: dry run. Do not actually execute anything, just print the commands that would be executed.
    --resume: resume executing the pipeline from a previous run.

  Stack assembly options:
    -M: number of mismatches allowed between stacks within individuals (for ustacks).
    -n: number of mismatches allowed between stacks between individuals (for cstacks; default 1; suggested: set to ustacks -M).

  SNP model options:
    --var-alpha: significance level at which to call variant sites (for gstacks; default: 0.05).
    --gt-alpha: significance level at which to call genotypes (for gstacks; default: 0.05).

  Paired-end options:
    --paired: after assembling RAD loci, assemble mini-contigs with paired-end reads.
    --rm-pcr-duplicates: remove all but one set of read pairs of the same sample that have
                         the same insert length.

  Population filtering options:
    -r,--min-samples-per-pop: minimum percentage of individuals in a population required to process a locus for that population (for populations; default: 0)
    -p,--min-populations: minimum number of populations a locus must be present in to process a locus (for populations; default: 1)
    
  Miscellaneous:
    --time-components (for benchmarking)
EOQ

    exit 1;
}
