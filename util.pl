#!/usr/bin/perl
#
use strict;
use warnings;
use 5.010;
use utf8;
use open ':std', ':encoding(UTF-8)';

sub ALog{
    my($filename, $content, $mode)=@_;
    my $fh;
    if($mode){
        open($fh, $mode,$filename);
    }else{
        open($fh, "+>>",$filename);
    }
    print $fh $content."\n";
}

sub writeTo{
    my($filename, $content, $mode)=@_;
    my $fh;
    if($mode){
        open($fh, $mode,$filename);
    }else{
        open($fh, ">",$filename);
    }
    print $fh $content;

}

sub makeArrHashFromArray{
    my ($delimeter, @in_jobs) = @_;
    my @jobs = ();

    my $headline=shift @in_jobs;
    chomp $headline;

    my @header = split $delimeter , $headline;

    foreach my $line (@in_jobs){
        my %item = ();
        chomp $line;

        my @fields = split $delimeter , $line;
        for my $i (0 .. $#header) {
            $item{$header[$i]} = $fields[$i];
        };
        push (@jobs, \%item);

    }

    return @jobs;
}

sub makeArrHashF{
    my ($file, $delimeter) = @_;
    my @jobs = ();

    open(my $data, '<', $file) or die "Could not open '$file' $!\n";

    my $headline= <$data>;
    chomp $headline;
    if (!$delimeter){
        $delimeter=',';
        if ($headline =~/\w+.*\t\w+/){
            $delimeter='\t';
        }
    }

    my @header = split $delimeter , $headline;
    while (my $line = <$data>) {
        my %item = ();
        chomp $line;

        my @fields = split $delimeter , $line;
        for my $i (0 .. $#header) {
            $item{$header[$i]} = $fields[$i];
        };
        push (@jobs, \%item);

    }

    return @jobs;
}

sub makeArrHash{
    my @jobs = ();
    my ($strContent, $delimiter, $columnCount)=@_;


    my @flag=1;
    if(! $columnCount){
        $columnCount=-1;
        # return @jobs;
    }

    my $lineno=0;
    my @header = ();

    my @line = split('\n', $strContent);

    # print "line:\n";
    # print Dumper(\@line);
    # print "line end:\n";

    my %item = {};
    foreach my $i (@line)
    {
        $i=~ s/^\s+//;
        my @fields = split($delimiter, $i, $columnCount);

        if ($lineno == 0){
            @header=@fields;
        }else{
            for my $i (0 .. $#header) {
                $item{$header[$i]} = $fields[$i];
            };
            push (@jobs, { %item });
            # push (@jobs,  \%item );

        }

        $lineno = $lineno + 1;
    }
    return @jobs;
}

sub fileName{
    my ( $path ) = @_;
    # /xxx/xxx/xxx
    # remove traling slash (if exist)
    $path =~ s|/$||;
    ($path) = $path =~ /(\/.+$)/;

    # last part of path
    my ($fname) = $path =~ /\/([a-zA-Z0-9_]+$)/;
    return $fname;
}

1;
