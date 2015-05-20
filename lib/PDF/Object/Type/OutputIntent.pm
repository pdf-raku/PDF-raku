use v6;

use PDF::Object::Dict;

# /Type /OutputIntent

class PDF::Object::Type::OutputIntent
    is PDF::Object::Dict
    does PDF::Object::Type {

    method S is rw { self<S> }
    method OutputCondition is rw { self<OutputCondition> }
    method OutputConditionIdentifier is rw { self<OutputConditionIndentifier> }
    method RegistryName is rw { self<RegistryName> }
    method Info is rw { self<Info> }
    method DestOutputProfile is rw { self<DestOutputProfile> }

}
