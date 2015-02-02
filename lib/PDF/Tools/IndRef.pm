use v6;

class PDF::Tools::IndRef {

    has Int $.obj-num is rw;
    has Int $.gen-num is rw;

    method ast {
        :ind-ref[ $.obj-num, $.gen-num ]
    }
}
