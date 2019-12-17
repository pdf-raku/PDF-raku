use v6;
unit role PDF::Interface;

# a definition of the methods implemented by PDF. Can be consumed by
# derived or replacement classes to ensure all methods are implemented.

method AT-KEY {...}
method ASSIGN-KEY {...}
method cb-finish {...}
method obj-num {...}
method gen-num {...}
method reader {...}
method open {...}
method update { ...}
method save-as {...}
method permitted {...}
method content {...}
method ast {...}
method Str {...}
method Blob {...}
method loader {...}
