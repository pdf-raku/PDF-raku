use v6;

use Digest::MD5;
use Crypt::RC4;

class PDF::Storage::Crypt::RC4 {

    submethod BUILD( Str :$owner-pass!, Str :$user-pass!, Hash :$trailer!) {
    }

}
