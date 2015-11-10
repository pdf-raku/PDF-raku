use v6;
use Test;
use PDF::Storage::Crypt;
use PDF::DAO::Doc;

my $test1 = do {
    my Hash $Encrypt = {
	:V(2),
	:Filter<Standard>,
	:Length(128),
	:O("\x[e6]\x0\x[ec]\x[c2]\x[2]\x[88]\x[ad]\x[8b]\rd\x[a9])\x[c6]\x[a8]>\x[e2]Qvy\x[aa]\x[2]\x[18]\x[be]\x[ce]\x[ea]\x[8b]y\x[86]rj\x[8c]\x[db]"),
	:U("\x[90]\x[e3]\x[10]\x[f5]\x[3]}\x[88]\x[d4]XG:^\x[a]\fB8\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0"),
	:P(-3904),
	:R(3),
    };

    my Str $doc-id = "4\t\x[c9]\x[89]\x[1b]<}\x[b8]\x[2]lp\x[b7]\x[fe]-\x[3]\x[e8]";
    
    { :doc{ :$Encrypt, :ID[$doc-id, $doc-id], }, :user-pass(''), :owner-pass<test> }
}

my $test2 = do {
    my Hash $Encrypt = {
	:V(2),
	:Filter<Standard>,
	:Length(128),
	:O("£\x[b]Y\$bÂòº\x[5]\x[4]¯\x[9c]êN\"'°¤9h\x[83]\@¾ò\x[a0]é)yVÑ8³"),
	:U("Í¢Z¦\x[16]jU\bH^õO\x[1]£l\x[6]\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0"),
	:P(-3904),
	:R(3),
    };

    my Str $doc-id = "0Þ\x[14]}÷9´ªik`\x[90]g=\x[90]à";
    
    { :doc{ :$Encrypt, :ID[$doc-id, $doc-id], }, :user-pass<test2>, :owner-pass<test1> }
}

my $doc;
my $crypt-delegate;

for $test1,
    $test1
 {

    $doc = PDF::DAO::Doc.new: .<doc>;
    my $owner-pass = .<owner-pass>;
    my $user-pass = .<user-pass>;
    my $crypt-delegate = PDF::Storage::Crypt.delegate-class( :$doc );

    isa-ok $crypt-delegate, ::('PDF::Storage::Crypt::RC4'), '/V 2 crypt delegate';

    my $crypt = $crypt-delegate.new( :$doc );
    lives-ok {$crypt.authenticate( $user-pass )}, 'user password';
    todo("owner password authentication");
    lives-ok {$crypt.authenticate( $owner-pass, :owner)}, 'owner password';
}

done-testing;
