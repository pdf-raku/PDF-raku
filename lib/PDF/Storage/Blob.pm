class PDF::Storage::Blob does Blob[uint8]  is repr('VMArray') {
    method encoding{  'latin-1' }
    multi method Str { self.decode("latin-1") }
    multi method Stringy { self.decode("latin-1") }
}
