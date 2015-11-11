use v6;
use Test;
use PDF::Storage::Crypt;
use PDF::DAO::Doc;

my $test1 = do {
    # pdftk output enc.pdf encrypt helloworld.pdf ownerpw test
    my Hash $Encrypt = {
	:V(2),
	:Filter<Standard>,
	:Length(128),
	:O("\x[e6]\x0\x[ec]\x[c2]\x[2]\x[88]\x[ad]\x[8b]\rd\x[a9])\x[c6]\x[a8]>\x[e2]Qvy\x[aa]\x[2]\x[18]\x[be]\x[ce]\x[ea]\x[8b]y\x[86]rj\x[8c]\x[db]"),
	:U("\x[90]\x[e3]\x[10]\x[f5]\x[3]}\x[88]\x[d4]XG:^\x[a]\fB8\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0"),
	:P(-3904),
	:R(3),
    };

    my $stream = "\x[ee]\x[8a]\x[9a]\x[0b]\x[c9]^S\x[03]}\x[ac]\x[8c]q\x[e5]\t\x[f1]tU\x[f8]\x[ce]\x[88]V\x[e5]5\x[bc]\x[b7]Q@A\x[cf]\x[1a]<\x[d3]\x[d3]~\x[b9]\x[be]\x[13]\x[b6]\x[0b]\x[06]\x[a6]\x[02]\x[a7]\x[bb]!\x[1b]";
    my Str $doc-id = "4\t\x[c9]\x[89]\x[1b]<}\x[b8]\x[2]lp\x[b7]\x[fe]-\x[3]\x[e8]";
    
    { :doc{ :$Encrypt, :ID[$doc-id, $doc-id], }, :user-pass(''), :owner-pass<test>, :$stream }
}

my $test2 = do {
    # pdftk output enc2.pdf encrypt helloword.pdf ownerpw test1 userpw test2
    my Hash $Encrypt = {
	:V(2),
	:Filter<Standard>,
	:Length(128),
	:O("£\x[b]Y\$bÂòº\x[5]\x[4]¯\x[9c]êN\"'°¤9h\x[83]\@¾ò\x[a0]é)yVÑ8³"),
	:U("Í¢Z¦\x[16]jU\bH^õO\x[1]£l\x[6]\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0"),
	:P(-3904),
	:R(3),
    };

    my $stream = "(\x[c2]B<r\x[97]\x[b3]\x[17]\x[fd]A@/Ps\x[1b]\x[c6]t\x[f2]\x[f2]\x[06]O\x[fb]\x[a2]\x[ed]3\x[10]M\x[12]\x[16]_W\n\x[99]\x[1d]\x[85]\x[fa]\x[b5]\x[fb]\x[b4]*\x[ff]V\x[a2]\x[93]3\x[9f]";
    my Str $doc-id = "0Þ\x[14]}÷9´ªik`\x[90]g=\x[90]à";
    
    { :doc{ :$Encrypt, :ID[$doc-id, $doc-id], }, :user-pass<test2>, :owner-pass<test1>, :$stream }
}

for $test1,
    $test1
 {
    my $doc = PDF::DAO::Doc.new: .<doc>;
    my $owner-pass  = .<owner-pass>;
    my $user-pass   = .<user-pass>;
    my $cipher-text = .<stream>;
    my $crypt-delegate = PDF::Storage::Crypt.delegate-class( :$doc );

    isa-ok $crypt-delegate, ::('PDF::Storage::Crypt::RC4'), '/V 2 crypt delegate';

    my $crypt = $crypt-delegate.new( :$doc );
    dies-ok  { $crypt.authenticate( 'blah' ) }, 'bad password';
    lives-ok { $crypt.authenticate( $user-pass ) }, 'user password';
    lives-ok { $crypt.authenticate( $owner-pass, :owner) }, 'owner password';

    my $obj-num = 6;
    my $gen-num = 0;
    my $length = 46;

    my $plain-text = "BT /F1 24 Tf  100 250 Td (Hello, world!) Tj ET";
    is $crypt.crypt(:$obj-num, :$gen-num, $cipher-text), $plain-text, 'decryption';
    is $crypt.crypt(:$obj-num, :$gen-num, $plain-text), $cipher-text, 'encryption';
}

done-testing;
