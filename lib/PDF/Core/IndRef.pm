use v6;

class PDF::Core::IndRef {

    has Int $.obj-num is rw;
    has Int $.gen-num is rw;

    method ast {
        :ind-ref[ $.obj-num, $.gen-num ]
    }
}
