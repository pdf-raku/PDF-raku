use v6;

use PDF::DAO::Doc;

class PDF::Storage::Crypt {

    method delegate-class( PDF::DAO::Doc :$doc! ) {
	return Nil
	    unless ($doc<Encrypt>:exists)
	    && ($doc<Encrypt><V>:exists);

	my $class = do given $doc.Encrypt.V {
	    when 1 | 2 | 3 {
		require ::('PDF::Storage::Crypt::RC4');
		::('PDF::Storage::Crypt::RC4');
	    }
	    default {
		die "unsupported encryption version: $_";
	    }
	}
	$class;
    }

}
