#!/usr/bin/perl -w
$|++;

### Name:	latex_2_tex.pl

### Author:	sweetser@alum.mit.edu

### License: 	in the public domain

our $VERSION = '$Revision: 1.1 $';

### Program Description

my $help_string = <<HELP;

Purpose: To get the format right for Drupal page  

Usage: latex_2_tex.pl [-output file.out] file_name

In a Mathematica notebook, select all (control a),
COPY as LaTeX
Open up a text file & paste.
Please check that all \text{} ARE ON ONE LINE.
Please check function names are in lower case, not UPPER.
Avoid LaTeX in a paragraph of text.

Run 
latex_2_tex.pl file_name -out file.out

Cut and past file.out to visualphysics.org
HELP

### Algorithm

# Read in line by line.
# Remove \text{   }, dollar signs
# Put in [tex][/tex]

### Modules

use strict;
use English;
use Getopt::Long;
$Getopt::Long::autoabbrev = 1;
$Getopt::Long::ignorecase = 0;
use FindBin qw($Bin);
use Data::Dumper;

### Variables

my $line;
my ( $output_file, $output_string );
my $mode        = 'not_tex';
my $last_mode   = 'not_tex';
my $blank_found = '';
my $tex_flag;
my $begin_flag;
my $begin_mode;
my $end_flag;

# Utility variables.
my $arg;
my $get;
my $command_run;
my ( $tmp, @tmp );
my $system_call;
my $help       = "";
my $test       = 0;
my $error_flag = 0;
my $QA;

### Main

__get_data();

while (<>) {

    $line = $_;
    chomp $line;

    # Toss out beginning and ending blank space.
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    next unless $line;

    # Odd character substitutions.
    $line =~ s/\{\\\" o\}/\&\#246\;/g;
    $line =~ s/\$//g;

    # Correct errors in \left, \right
    $line =~ s/\\left[^\(\[\{\|\)\}\]]//g;
    $line =~ s/\\right[^\(\[\{\|\)\}\]h]//g;

    # Italics
    $line =~ s/\\text\{\\textit\{(.*)}}{1}/\\text\{<em>$1<\/em>\}/g;
    $line =~ s/\\textit\{(.*)\}{1}/<em>$1<\/em>/g;
    $line =~ s/\}<\/em>/<\/em>\}/g;

    # Bold
    $line =~ s/\\pmb\{\\text\{(.*?)\}\}/\\text\{<b>$1<\/b>\}/g;
    $line =~ s/\\pmb\{(.*?)\}{1}/\\text\{<b>$1<\/b>\}/g;

    # Quotes
    $line =~ s/\{\`\`\}/\"/g;
    $line =~ s/\{\'\'\}/\"/g;

    # Boxtimes symbol
    $line =~ s/text\{(boxtimes)\}/boxtimes/g;

    # Vectors
    $line =~ s/overset\{\\rightharpoonup \}/vec/g;

    # Check squares are in the right place.
    $line =~ s/\s\^/\^/g;

    # Handle returns for non_tex and tex differently.
    if ( $line =~ /^\\text/ ) {
        $mode = "not_tex";
        $line =~ s/^\\text.//;
        $line =~ s/\}$//;

        if ( ( $last_mode eq 'not_tex' ) and !$tex_flag ) {
            $line = "\n\n<p>" . $line;
        }

        $tex_flag = 0;
        $tex_flag = 1 if ( $line =~ /\[tex\]/ );
        if ($end_flag) {
            $end_flag = 0;
            $line     = "[/tex]" . $line;
        }
    }
    # Next 4 elsif's handle \begin..\end LaTeX
    elsif ( $line =~ /\\begin/ ) {
        $begin_flag = 1;
        $begin_mode = $last_mode;
        if ( $begin_mode eq "tex" ) {
            $output_string =~ s/\[\/tex\]\s*$//;
            $line = "\n" . $line . "\n";
        }
        else {
            $line = "\n\n[tex]" . $line . "\n";
        }
    }
    elsif ($end_flag) {
        $end_flag = 0;
        if ( $begin_mode eq "tex" ) {
            $line .= "[/tex]\n\n<p>";
        }
        else {
            $line = "[/tex]iHELLO<p>" . $line;
        }
    }
    elsif ( $line =~ /\\end/ ) {
        $begin_flag = 0;
        $end_flag   = 1;
        $line .= " ";
    }
    elsif ($begin_flag) {

        # no need to alter the text other than add a space.
        $line .= "\n";
    }
    # Separate [tex] lines [/tex]
    elsif ( $line =~ /^=\\text/ ) {
        $mode = "tex";
        $line =~ s/^=\\text./=/;
        $line =~ s/\}\s+?$//;
        if ($tex_flag) {

            # Do nothing to the line.
        }
        else {
            $line = "\n\n[tex]" . $line . "[/tex]";
        }
    }
    else {
        $mode = "tex";
        if ($tex_flag) {

            # Do nothing to the line.
        }
        else {
            $line = "\n\n[tex]" . $line . "[/tex]";
        }
    }

    # Remove remaining text{}'s
    while ( $line =~ /\\text\{(.*)\}{1}/ ) {
        $line =~ s/(.*)\\text\{(.*?)\}{1}/$1$2/;
    }

    # Remove any <em> tags from tex lines.
    if ( ( $mode eq "tex" ) and ( $line =~ /<em>/ ) ) {
        $line =~ s/<\/?em>//g;
    }

    $last_mode = $mode;

    $output_string .= $line;
}

# Rewrite any functions to tex form
$output_string =~ s/ArcCos\}/\\arccos/g;
$output_string =~ s/ArcTan\}/\\arctan/g;
$output_string =~ s/ArcTanh/\\arctanh/g;
$output_string =~ s/arctanh/\\text\{arctanh\}/g;
$output_string =~ s/\\?backslash//g;

# Delete starting/ending spaces and returns.
$output_string =~ s/^[\s\n]+//;
$output_string =~ s/[\s\n]+$//;

# Print modified lines.
open OUTPUT, ">$output_file" || die "Unable to open file $output_file: $!";
print OUTPUT $output_string;
print STDOUT $output_string;
close OUTPUT;

my $line_count = `wc -l $output_file`;

print STDERR "\n\nline number count: $line_count";

### Signals

exit($error_flag);

### Subroutines

# Get data, assign to variables.
sub __get_data {

    $command_run = "$0 @ARGV";

    # Get options.
    $get = GetOptions(
        "output_file=s" => \$output_file,
        "test!"         => \$test,
        "QA!"           => \$QA,
        "help"          => \$help,
    );

    die ("Check options please.\nProgram exiting.\n") unless $get;

    die "Please provide a file_name at the command line.\nProgram exiting.\n"
      unless -e "$ARGV[0]";

    if ($help) {
        print $help_string;
        exit(1);
    }

    unless ($output_file) {

        $output_file = $ARGV[0];

        if ( $output_file =~ /\.txt$/ ) {
            $output_file =~ s/\.txt$/_tex.txt/;
        }
        else {
            $output_file .= ".tex";
        }
    }
}
