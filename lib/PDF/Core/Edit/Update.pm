use v6;

use PDF::Core::Edit;
use PDF::Core::IndObj;
use PDF::Core::IndRef;

class PDF::Core::Edit::Update
    is PDF::Core::Edit {
        has PDF::Core::IndObj $.ind-ref is rw; #| object begin updated
        has PDF::Core::IndObj $.ind-obj is rw; #| new versio of the object
}
