use v6;
use Test;

use PDF::DAO::Doc;

my $doc = PDF::DAO::Doc.open: "t/helloworld.pdf";

my $user-pass = '';
my $owner-pass = 'ssh!';

lives-ok { $doc.encrypt( :$owner-pass, :$user-pass, :R(2), :V(1), ) }, '$doc.encrypt (R2.1) - lives';
lives-ok {$doc.save-as: "t/encrypt.pdf"}, '$doc.save-as - lives';
dies-ok { $doc = PDF::DAO::Doc.open: "t/encrypt.pdf", :password<dunno> }, "open encrypted without a password - dies";
lives-ok { $doc = PDF::DAO::Doc.open("t/encrypt.pdf", :password($user-pass)) }, 'open with user password - lives';
is $doc.crypt.is-owner, False, 'open with user password - not is-owner';
lives-ok { $doc = PDF::DAO::Doc.open("t/encrypt.pdf", :password($owner-pass)) }, 'open with owner password - lives';
is $doc.crypt.is-owner, True, 'open with owner password - is-owner';
done-testing;
