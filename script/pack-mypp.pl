#!/usr/bin/perl

use strict;
use warnings;

open my $MODULE, '<', 'lib/App/Mypp.pm' or die $!;
open my $BIN, '<', 'bin/mypp' or die $!;
open my $OUT, '>', 'bin/mypp-packed' or die $!;

my $print = 1;
my $record = q();
my $synopsis = q();

print $OUT scalar <$BIN>; # she-bang

while(<$MODULE>) {
    if(/^use (?:strict|warnings)/) {
        next;
    }
    if(/^=/) {
        $record = q();
        $print = 0 
    }
    if($record eq 'synopsis' and !$print) {
        $synopsis .= $_ 
    }
    if(/\S/ and $print) {
        s/^\s+//;
        print $OUT $_;
    }
    if(/^sub help/) {
        print $OUT "print '$synopsis';\n}";
        $print = 0;
    }
    if(/^=cut/ or /^}/) {
        $print = 1;
    }
    if(/^=head1 SYNOPSIS/) {
        $record = 'synopsis';
    }
}

print $OUT "\nBEGIN { \$INC{'App/Mypp.pm'} = 1 }\n";
print $OUT "\n#", "=" x 78, "\n";

while(<$BIN>) {
    next if /^use (?:strict|warnings)/;
    s/^\s+//;
    print $OUT $_ if /\S/ and $print;
}


print "packed\n";
