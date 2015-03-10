use v6;

role t::Reserialize {

#| run a short experimental reserializion of this object
    method reserialize {
        my $result = $.object.serialize;
        my $ast-regen = :ind-obj[ $.obj-num, $.gen-num, $result<objects>[*-1].value[2] ];
        $ast-regen;
    }

}
