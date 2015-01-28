use v6;

use PDF::Core::Edit;
use PDF::Core::IndObj;

class PDF::Core::Edit::Add
    is PDF::Core::Edit {
        has PDF::Core::IndObj $.ind-obj is rw;
}
