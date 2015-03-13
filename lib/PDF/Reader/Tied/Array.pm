use v6;

use PDF::Reader::Tied;

role PDF::Reader::Tied::Array
    does PDF::Reader::Tied {

    method ACCEPTS(*@arg) {
        my $result := callsame;
        warn "ACCEPTS {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method ASSIGN-POS(*@arg) {
        my $result := callsame;
        warn "ASSIGN-POS {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method AT-POS(*@arg) {
        my $result := $.tied( callsame );
        warn "AT-POS {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method BIND-POS(*@arg) {
        my $result := callsame;
        warn "BIND-POS {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method DELETE-POS(*@arg) {
        my $result := callsame;
        warn "DELETE-POS {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method DUMP(*@arg) {
        my $result := callsame;
        warn "DUMP {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method EXISTS-POS(*@arg) {
        my $result := callsame;
        warn "EXISTS-POS {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method FLATTENABLE_HASH(*@arg) {
        my $result := callsame;
        warn "FLATTENABLE_HASH {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method FLATTENABLE_LIST(*@arg) {
        my $result := callsame;
        warn "FLATTENABLE_LIST {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method PARAMETERIZE_TYPE(*@arg) {
        my $result := callsame;
        warn "PARAMETERIZE_TYPE {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method REIFY(*@arg) {
        my $result := callsame;
        warn "REIFY {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method STORE(*@arg) {
        my $result := callsame;
        warn "STORE {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method STORE_AT_POS(*@arg) {
        my $result := callsame;
        warn "STORE_AT_POS {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

 }
