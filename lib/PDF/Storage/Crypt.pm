use v6;

use Digest::MD5;
use Crypt::RC4;

class PDF::Storage::Crypt {

    method delegate-class( Hash :$trailer! ) {
	return Nil
	    unless ($trailer<Encrypt>:exists)
	    && ($trailer<Encrypt><V>:exists);

	my $class = do given $trailer<Encrypt><V> {
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

    submethod BUILD( Str :$owner-pass, Str :$user-pass!, Hash :$trailer!) {
    }

}
