use v6;

use PDF::Storage::Crypt::AST;

class PDF::Storage::Crypt::Doc
    does PDF::Storage::Crypt::AST {
    use PDF::Storage::Crypt;
    use PDF::Storage::Crypt::RC4;
        

    has PDF::Storage::Crypt $!stm-f handles <is-owner>; #| stream filter (/StmF)
    has PDF::Storage::Crypt $!str-f; #| string filter (/StrF)

    submethod BUILD(:$doc!, Str :$owner-pass, |c) {
        $owner-pass
            ?? self.generate( :$doc, :$owner-pass, |c)
            !! self.load( :$doc, |c)
    }

    #| generate encryption
    submethod generate( Hash :$doc!, :$R = 3, |c ) {
        die "can't generate encryption with /R > 3 yet"
            if $R > 3;
        $!stm-f = PDF::Storage::Crypt::RC4.new( :$doc, :$R, |c );
        $!str-f := $!stm-f;
    }
        
    #| read existing encryption
    submethod load( Hash :$doc!, |c ) is default {
	die "document is not encrypted"
            unless $doc<Encrypt>:exists;

        my $encrypt = $doc<Encrypt>;
        PDF::DAO.delegator.coerce($encrypt, PDF::DAO::Type::Encrypt);
        
	given $encrypt.R {
	    when 1..3 {
                # stream and string channels are identical
                $!stm-f = PDF::Storage::Crypt::RC4.new( :$doc, |c );
                $!str-f := $!stm-f;
	    }
            when 4 {
                # Determined by /CF /StmF and /StrF entries
                die "V4 encryption is NYI";
            }
	    default {
		die "unsupported encryption version: $_";
	    }
	}
    }

    multi method crypt(:$key! where 'hex-string' | 'literal', |c) {
        $!str-f.crypt(|c);
    }

    multi method crypt(|c) is default {
        $!stm-f.crypt(|c);
    }

    method authenticate( $pass ) {
        $!str-f.authenticate($pass);
        $!stm-f.authenticate($pass)
            unless $!str-f === $!stm-f;
    }

}
