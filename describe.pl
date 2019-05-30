#!/usr/bin/perl
#
use warnings;
use 5.010;
use Storable;

use Data::Dumper;
require "var.pl";
require "util.pl";

my $update = $ARGV[0];

my $filename="./tbl_col_type.dat";

if ($update eq 1 || ! -e $filename){
    dump_tbl_col();
}

if ($update eq 0){
    load_tbl_col();
}
# test for load table column info from previously stored file
sub load_tbl_col{
    my $hash2 = retrieve($filename);
    my %hash2 = %{$hash2};

    # open my $fh, "<$filename" or die "Can not open $filename";
    # %hash2 = split(",", <$fh>);
    # close $fh;
    # print Dumper(\%hash2);

    my $tt = $hash2{'app_ap_location_5mm'};
    say $hash2{'app_ap_location_5mm'};
    say $tt->{'month'};
    say $hash2{'app_ap_location_5mm'}{'month'};
    foreach my $name (sort keys %hash2) {
        foreach my $subject (keys %{ $hash2{$name} }) {
            print "$name, $subject: $hash2{$name}{$subject}\n";
        }
    }
}

sub dump_tbl_col{
    my @table = `impala-shell -i $impala_host:$impala_port -q 'invalidate metadata; use idata; show tables'`;
    if ($? != 0){
        die "impala-shell exit with code: $?";
    }
    @table= map { ($_) =~/(\w+[_|\w+]*\w+)/ } @table;
    shift @table;

    my %tbl_col_type = {};

    foreach(@table){
        if (/^tmp_/){
            next;
        }
        say $_;
        my $tblname=$_;
        my @des_tbl = `impala-shell -i $impala_host:$impala_port -q 'use idata; describe $_'`;
        @des_tbl = map { chomp $_; ($_) =~/([^+-].*)/; } @des_tbl;
        @des_tbl = map { chomp $_; $_ =~ s/\|/,/g; $_ } @des_tbl;
        @des_tbl = map { chomp $_; $_ =~ s/^,| //g; $_ } @des_tbl;

        my @columns=makeArrHashFromArray(',', @des_tbl);

        my %col_type = map {$_->{'name'} => $_->{'type'}} @columns;
        # print Dumper(\@columns);
        $tbl_col_type{$tblname} = { %col_type };
        # push @tbl_col_type, {$tblname => {%col_type}};

    }
    store(\%tbl_col_type, $filename);
 }
