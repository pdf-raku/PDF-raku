use Test;

plan 4;

use PDF::Storage::Filter;

my $in = 'Man is distinguished, not only by his reason, but by this singular passion from other animals, which is a lust of the mind, that by a perseverance of delight in the continued and indefatigable generation of knowledge, exceeds the short vehemence of any carnal pleasure.';
my $out = q:to"--END--".chomp;
9jqo^BlbD-BleB1DJ+*+F(f,q/0JhKF<GL>Cj@.4Gp$d7F!,L7@<6@)/0JDEF<G%<+EV:2F!,O<DJ+*.@<*K0@<6L(Df-\0Ec5e;DffZ(EZee.Bl.9pF"AGXBPCsi+DGm>@3BB/F*&OCAfu2/AKYi(DIb:@FD,*)+C]U=@3BN#EcYf8ATD3s@q?d$AftVqCh[NqF<G:8+EV:.+Cf>-FD5W8ARlolDIal(DId<j@<?3r@:F%a+D58'ATD4$Bl@l3De:,-DJs`8ARoFb/0JMK@qB4^F!,R<AKZ&-DfTqBG%G>uD.RTpAKYo'+CT/5+Cei#DII?(E,9)oF*2M7/c~>
--END--

my %dict = :Filter<ASCII85Decode>;

is(PDF::Storage::Filter.encode($in, :%dict).Str.subst(/\n/,"", :g),
   $out,
   q{ASCII85 test string is encoded correctly});

is(PDF::Storage::Filter.encode($in, :%dict),
   $out,
   q{ASCII85 test string with EOD marker is encoded correctly});

is(PDF::Storage::Filter.decode($out, :%dict),
   $in,
   q{ASCII85 test string with EOD marker is decoded correctly});

# Check for death if invalid characters are included
dies-ok { PDF::Storage::Filter.decode('This is not valid input{|}', :%dict) }, q{ASCII85 dies if invalid characters are passed to decode};

