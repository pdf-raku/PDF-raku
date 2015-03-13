use v6;

use PDF::Reader::Tied;

role PDF::Reader::Tied::Hash
    does PDF::Reader::Tied {

    method ACCEPTS(*@arg) {
        my $result := callsame;
        warn "ACCEPTS {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method ASSIGN-KEY(*@arg) {
        my $result := callsame;
        warn "ASSIGN-KEY {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method AT-KEY($key!) {
        my $result := $.tied( callsame );
        warn "AT-KEY {{ :$key}.perl} --> {$result.perl}";
        $result;
    }

    method BIND-KEY(*@arg) {
        my $result := callsame;
        warn "BIND-KEY {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    # DELETE-KEY

    method DUMP(*@arg) {
        my $result := callsame;
        warn "DUMP {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    # EXISTS-KEY()

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

    method STORE(*@arg) {
        my $result := callsame;
        warn "STORE {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method STORE_AT_KEY(*@arg) {
        my $result := callsame;
        warn "STORE_AT_KEY {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }
}
