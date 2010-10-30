#!/usr/bin/perl -w
$|++;

### Name:	latex_2_tex.pl

### Author:	sweetser@alum.mit.edu

### License: 	in the public domain

our $VERSION = '$Revision: 1.1 $';

### Program Description

my $help_string = <<HELP;

Purpose: To get the format right for Drupal page  

Usage: STDIN | latex_2_tex.pl [-output file.out] file.txt

Can take STDIN, produce STDOUT.

Default: if no -output is set, creates file_tex.txt
The contents of file_tex.txt can be pasted into any
field that understand [tex]x^2[/tex] markup.

Note: also prints to screen

In a Mathematica notebook, select all (control a),
COPY AS LaTeX
Open up a text file & paste.
Please check that all \text{} ARE ON ONE LINE.
Please check function names are in lower case, not Upper.

Run 
latex_2_tex.pl file.txt

Cut and past file_tex.tex to web page.
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
my $mode        = '';
my $last_mode   = 'none';
my $blank_found = '';
my $first_line_flag = 1;
my $tex_flag;
my $begin_flag;
my $begin_mode;
my $end_flag;
my $equal_flag;
my ($anchor, @anchors);
my $anchor_number = 1;
my $links;
my $eq_counter = 1;
my $number_all;

# Utility variables.
my $arg;
my $get;
my $command_run;
my ( $tmp, @tmp );
my $system_call;
my $help       = "";
my $test       = 0;
my $error_flag = 0;
my $QA = 1;

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
    $line =~ s/unicode\{22a0\}/boxtimes/g;

    # Vectors
    $line =~ s/overset\{\\rightharpoonup \}/vec/g;

    # Check squares are in the right place.
    $line =~ s/\s\^/\^/g;

    # Delete rights with no lefts.
    # Could make fancier counting # of rights and lefts.
    if ( ($line =~ /\\right/) and ($line !~ /\\left/)) {
        $line =~ s/\\right//g;
    }

    # Handle returns for non_tex and tex differently.
    #  $output_string .= "INPUT line: $line\n";
    if ($first_line_flag) {
       $line =~ s/.*\\text.//;
       $line =~ s/\}$//;
       $first_line_flag = 0;

       if ( $line =~ /^\d+\./ ) {
            push @anchors, $line;
            $line = qq(\n\n\n<h2><a name="$anchor_number">) . $line . "</a></h2>\n";
            $anchor_number += 1;
        }
        else {
            $line .= "\n\n";
        }
    }
    elsif ( $line =~ /^\\text/ ) {
        $mode = "not_tex";
        $equal_flag = 0;

        $line =~ s/^\\text.//;
        $line =~ s/\}$//;

        if ( $line =~ /^\d+\./ ) {
            push @anchors, $line;
            $line = qq(\n\n\n<h2><a name="$anchor_number">) . $line . "</a></h2>\n";
            $anchor_number += 1;
        }
        elsif ( ( $last_mode eq 'not_tex' ) and !$tex_flag ) {
            $line = "\n\n<p>" . $line;
        }
        elsif ( ( $last_mode eq 'tex' ) and !$tex_flag ) {
            $line = "\n\n<p>" . $line;
        }

        # The tex_flag is for latex within a paragraph.
        # It is set _unless_ the line ends in 
        # a perios, colon, semicolon, or question mark.
        $tex_flag = 0;
        $tex_flag = 1 if ( $line =~ /[^\.\:\;\?]$/ );
 
        if ($end_flag) {
            $end_flag = 0;
            $line     = " \\quad eq. $eq_counter [/tex]" . $line;
            $eq_counter += 1;
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
        $equal_flag = 1;
        $line =~ s/^=\\text./=/;
        $line =~ s/\}\s+?$//;
        if ($tex_flag) {
            $line = "[tex]" . $line . "[/tex]";
        }
        else {
            $line = "\n\n[tex]" . $line . "[/tex]";
        }
    }
    else {
        $mode = "tex";
        if ($tex_flag or $equal_flag) {
            $line = "[tex]" . $line . "[/tex]";
        }
        else {
            if ($last_mode eq "not_tex") {
                $line = "\n\n[tex]" . $line . " \\quad eq. $eq_counter [/tex]";
                $eq_counter++;
            }
            else {
                if ($number_all) {
                    $line = "\n\n[tex]" . $line . " \\quad eq. $eq_counter [/tex]";
                    $eq_counter += 1;
                }
                else {
                    $line = "\n\n[tex]" . $line . "[/tex]";
                }
            }
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

# Generate the links.
$anchor_number = 0;
foreach $anchor (@anchors) {
    $anchor_number += 1;
    $links .= qq(<a href="\#) . $anchor_number . qq(">$anchor</a>\n);
}
$output_string = $links . $output_string;

# Print modified lines.
print STDOUT $output_string;

if ($output_file) {
    open OUTPUT, ">$output_file" || die "Unable to open file $output_file: $!";
    print OUTPUT $output_string;

    close OUTPUT;
    my $line_count = `wc -l $output_file`;

    print STDERR "\n\nline number count: $line_count";
}

### Signals

exit($error_flag);

### Subroutines

# Get data, assign to variables.
sub __get_data {

#   $command_run = "$0 @ARGV";

    # Get options.
    $get = GetOptions(
        "number_all!" => \$number_all,
        "output_file=s" => \$output_file,
        "test!"         => \$test,
        "QA!"           => \$QA,
        "help"          => \$help,
    );

    die ("Check options please.\nProgram exiting.\n") unless $get;

    if ($help) {
        print $help_string;
        exit(1);
    }

    if ($ARGV[0] and !$output_file) {

        $output_file = $ARGV[0];

        if ( $output_file =~ /\.txt$/ ) {
            $output_file =~ s/\.txt$/_tex.txt/;
        }
        else {
            $output_file .= ".tex";
        }
    }
}
