use v6;
use Test;
use PDF::Storage::Crypt;
use PDF::DAO::Doc;

my $test1 = do {
    # pdftk output enc.pdf helloworld.pdf owner_pw test
    my Hash $Encrypt = {
      :V(1),
      :Filter<Standard>,
      :U("\%\x[7f]d°BPa\x[90]\x[8d]\x[8d]\x[e]Ð´'\x[3]\x[1]30\tË¤_\bóÙ'»\x[1f]\x[96][ß\x[93]"),
      :R(2),
      :P(-64),
      :O("É\$\"h\x[7f]¬îhn7?\x[10]µÇÐG8\x[5]1R÷âî0á\x[1c]iìD\%v«"),
    };

    my $crypt = "åFðë)\x[8a]ø\x[6]}ðFî\x[3]\x[1a]7«Á\x[8b]7\"?^/l\x[a0]Áºqíp\x[13]H\x[3]7êß?ê\x[17]ÒGÉi/¡\x[89]";
    my Str $doc-id = "0\x[8a]Ú\x[1a]D\x[7f]'Ë7äþÙÌ\x[94]»§";
    
    { :doc{ :$Encrypt, :ID[$doc-id, $doc-id], }, :user-pass(''), :owner-pass<owner>, :$crypt }
}

my $test2 = do {
    # pdftk helloworld.pdf output enc2.pdf owner_pw test1 user_pw test2
    my Hash $Encrypt = {
	:V(2),
	:Filter<Standard>,
	:Length(128),
	:O("£\x[b]Y\$bÂòº\x[5]\x[4]¯\x[9c]êN\"'°¤9h\x[83]\@¾ò\x[a0]é)yVÑ8³"),
	:U("Í¢Z¦\x[16]jU\bH^õO\x[1]£l\x[6]\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0"),
	:P(-3904),
	:R(3),
    };

    my $crypt = "(\x[c2]B<r\x[97]\x[b3]\x[17]\x[fd]A@/Ps\x[1b]\x[c6]t\x[f2]\x[f2]\x[06]O\x[fb]\x[a2]\x[ed]3\x[10]M\x[12]\x[16]_W\n\x[99]\x[1d]\x[85]\x[fa]\x[b5]\x[fb]\x[b4]*\x[ff]V\x[a2]\x[93]3\x[9f]";
    my Str $doc-id = "0Þ\x[14]}÷9´ªik`\x[90]g=\x[90]à";
    
    { :doc{ :$Encrypt, :ID[$doc-id, $doc-id], }, :user-pass<test2>, :owner-pass<test1>, :$crypt }
}

for $test1,
    $test2
 {
    my $doc = PDF::DAO::Doc.new: .<doc>;
    my $owner-pass  = .<owner-pass>;
    my $user-pass   = .<user-pass>;
    my $cipher-text = .<crypt>;
    my $crypt-delegate = PDF::Storage::Crypt.delegate-class( :$doc );

    isa-ok $crypt-delegate, ::('PDF::Storage::Crypt::RC4'), "/V {$doc.Encrypt.V}.{$doc.Encrypt.R} crypt delegate";

    my $crypt = $crypt-delegate.new( :$doc );
    dies-ok  { $crypt.authenticate( 'blah' ) }, 'bad password';
    lives-ok { $crypt.authenticate( $user-pass ) }, 'user password';
    ok ! $crypt.is-owner, 'is not owner';
    lives-ok { $crypt.authenticate( $owner-pass, :owner) }, 'owner password';
    ok $crypt.is-owner, 'is owner';

    my $obj-num = 6;
    my $gen-num = 0;
    my $length = 46;
    my $plain-text = "BT /F1 24 Tf  100 250 Td (Hello, world!) Tj ET";

    is-deeply $crypt.crypt(:$obj-num, :$gen-num, $cipher-text), $plain-text, 'decryption';
    is-deeply $crypt.crypt(:$obj-num, :$gen-num, $plain-text), $cipher-text, 'encryption';

    my $encoded = $cipher-text;
    my $ast = :ind-obj[ $obj-num, $gen-num,
			:stream{
			    :dict{ :Length{ :int($length) } },
			    :$encoded,
			}];

    $encoded = $plain-text;
    my $ast-decrypted = :ind-obj[ $obj-num, $gen-num,
			      :stream{
				  :dict{ :Length{ :int($length) } },
				  :$encoded,
				  }];

    $crypt.crypt-ast($ast);
    is-deeply $ast, $ast-decrypted, 'ast decryption';
}

done-testing;
