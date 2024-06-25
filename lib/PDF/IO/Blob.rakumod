unit class PDF::IO::Blob does Blob[uint8] is repr('VMArray');

use PDF::IO;
also does PDF::IO;

method encoding{ 'latin-1' }
method codes { self.bytes }
multi method Str { self.decode: "latin-1" }
multi method Stringy { self.decode: "latin-1" }

multi method COERCE(::?CLASS $_) is default { $_ }
multi method COERCE(Blob $_) { self.new($_) }

