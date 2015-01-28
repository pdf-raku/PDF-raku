use v6;

use PDF::Core::Edit;
use PDF::Core::IndRef;

class PDF::Core::Edit::Add
    is PDF::Core::Edit {
        has PDF::Core::IndRef $.ind-ref is rw;
}
