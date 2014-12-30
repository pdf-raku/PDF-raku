use v6;

use PDF::Basic::IndObj::Stream;

# /Type /ObjStm - a stream of (usually compressed) objects
# introduced with PDF 1.5 
class PDF::Basic::IndObj::ObjStm
    is PDF::Basic::IndObj::Stream;

