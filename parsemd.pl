#!/usr/bin/perl
#
use 5.010;
use warnings;
use Storable;
use Getopt::Long;
use Data::Dumper;

# All use utf8; does is tell Perl the source code is encoded using UTF-8. You need to tell Perl how to encode your text:
use utf8;
use open ':std', ':encoding(UTF-8)';

use constant {
    RESVALUE => 0,
    RESSTRING => 1,
    RESOBJECT => 2,
    RESARRAY => 3,
};


require "util.pl";

my $request_prefix="/api";
my $modelName = 'experienceInsight';
my $submodelName = 'wifiuser';

my %pairsymbol=("]"=> "[", "}" =>"{");
my $file2parse = '';
my $help=0;

GetOptions( 'f=s' => \ $file2parse
            , 'h' => \ $help
            , 'm=s' => \ $modelName
    );

if ($help){
    usage();
    exit;
}

my $lineno=0;
my @iflist = ();

parseMD();
generateJSScript();

sub parseMD{
    # $file2parse is global v
    if ( -e $file2parse ){
        open ( my $in, "<:encoding(utf8)", $file2parse ) or die "$file2parse: $!";

        my $mockContent = "export default \{\n";
        my $responseContents='';

        while (my $line = <$in>) {
            $lineno = $lineno + 1;
            chomp $line;
            # skip comment
            if ($line =~ /^#/ or $line =~ /^-/){
                next;
            }
            $line=~ s/^\s+//;
            if (my ($httpmethod) = $line =~ /^([gGpP][a-zA-Z]+)\s/){
                my %interface=();

                # /xxx/xxx/xxx
                my ($reqpath) = $line =~ /(\/.+$)/;

                # last part of path
                my ($funcname) = $reqpath =~ /\/([a-zA-Z0-9_]+$)/;

                $interface{'method'} = uc $httpmethod;
                $interface{'reqpath'} = $reqpath;
                $interface{'func'} = $funcname;
                my @params = seekparam($in);
                my ( $restype, $response) = seekdata($in);
                $interface{'datatype'} = $restype;
                $interface{'params'} = \@params;
                # $responseContents .= "$response,\n";

                $mockContent .= "\'$httpmethod $request_prefix$reqpath\':\n";
                $mockContent .= "$response,\n";
                push(@iflist, \%interface);

            }
        }

        $mockContent = "$mockContent\n\}";
        say "------------------------------mock";
        writeTo("mock.js", $mockContent);

        # print Dumper(\@iflist);
        close $in;
    }
}

sub seekparam{
    my ($in) = @_;
    my $parambegin=0;
    my @params=();
    my @stk;
    while( my $line = <$in> ){
        $lineno = $lineno + 1;
        chomp $line;
        $line=~ s/^\s+|\s+$//g;
        # if ($line =~ /^参数/){
        #     say "------------find param";
        # }

        # if ($line =~ /^\}/ and $parambegin == 1){
        #     # print Dumper(\@params);
        #     return @params;
        # }

        if(skipletter($line)){
            next;
        }

        foreach my $char (split //, $line){
            if ($char eq "{" or $char eq "["){
                push(@stk, $char);
                next;
            }else{

                my $possible = $pairsymbol{$char};
                if($possible){
                    my $x = pop(@stk);
                    if (! $x eq $possible){
                        parseerror("expect $possible, but we get $x", 1);
                    }

                    if (! @stk){
                        return @params;
                    }
                    next;
                }
            }
        }

        if ($line =~ /^\{/){
            # reach data section
            if ($parambegin == 0){
                $parambegin = 1;
            }else{
                ParseError("seekparam: unexpected data section");
            }
            next;
        }

        if (my ( $paramname ) = $line =~ /^"(\w+)":.+/){
            push (@params, $paramname);
        }
    }
}

sub seekdata{
    my ($in) = @_;
    my $databegin=0;
    my $datatype = 0;
    my $responseContent = '';
    my @stk;


    while( my $line = <$in> ){
        $lineno = $lineno + 1;
        chomp $line;
        $line=~ s/^\s+|\s+$//g;
        # remove comment //***
        $line=~ s/(.*)\/\/.*/\1/;

        if(skipletter($line)){
            next;
        }

        $responseContent .= $line;

        foreach my $char (split //, $line){
            if ($char eq "{" or $char eq "["){
                push(@stk, $char);
                next;
            }else{

                my $possible = $pairsymbol{$char};
                if($possible){
                    my $x = pop(@stk);
                    if (! $x eq $possible){
                        parseerror("expect $possible, but we get $x", 1);
                    }

                    if (! @stk){
                        return ( $datatype, $responseContent );
                    }
                    next;
                }
            }
        }


        if ($line =~ /^\"data\"/){
            # reach data section
            if ($databegin == 0){
                $databegin = 1;
            }
            # datatype?
            my $lastchar = substr $line, -1;
            if ($lastchar eq '{' ){
                $datatype = RESOBJECT;
            }elsif($lastchar eq '['){
                $datatype = RESARRAY;
            }else{
                my ($val) = $line =~ /.+:(.+$)/;
                if ($val =~ /^\w+$/){
                    $datatype = RESVALUE;
                }else{
                    ParseError("unknow value for data $val");
                }
            }
            next;
        }
    }


    print Dumper(\@stk);
    return ( $datatype, $responseContent );
}

sub skipletter{
    my ( $ch ) = @_;
    if ($ch =~ /^#/ or $ch =~ /^-/ or $ch =~ /^`/){
        return 1;
    }

    if ($ch =~ /^(\p{Han}+)/ ) {
        return 1;
    }

    return 0;
}

sub defvalue{
    my ($datatype) = @_;
    if ($datatype == RESVALUE){
        return 0;
    }elsif($datatype == RESARRAY){
        return '[]';
    }elsif($datatype == RESOBJECT){
        return '{}';
    }elsif($datatype == RESSTRING){
        return '\'\'';
    }
}

sub generateJSScript{
    # models
    my $effects = '';
    my $variables = '';
    my $services = '';
    my $modelContent = "import {\n";
    my $serviceContent = "import request from '../../utils/oauthFetch';\n\n";
    my $requestContent ='';

    foreach (@iflist){
        my $funcname = $_->{'func'};
        my $varname = $funcname . 'data ';
        $modelContent .= $funcname;
        $modelContent .= ",\n";

        my $var = $varname . ':' . defvalue($_->{'datatype'});
        my $effect = "  *$funcname({payload}, { call, put }) {
        const response = yield call($funcname, payload);
        if(response&&response.success){
        yield put({
      type: 'update',
        payload: {
        $varname: response.data
      }
              });
        }
                                                                       },\n\n";

        my $serviceparam = '';
        my $bodypart ='';
        my $params = $_->{'params'};
        my $httpmetohd=$_->{'method'};
        my $payloadmap='';
        my $reqfunArguments='';
        if (@$params){
            foreach (@$params){
                if ($httpmetohd =~ /GET/){
                    $serviceparam .= "\${params.$_}/";
                }
                $reqfunArguments .= " _$_,";
                $payloadmap .= "$_: _$_,\n";
            }

            # trim the last one ','
            $reqfunArguments =~ s/(.+),$/\1/;
            if ($reqfunArguments){
                $reqfunArguments = ','.$reqfunArguments;
            }
        }

        if ($_->{'method'} =~ /POST/){
            $bodypart .= "\n    body: \{
            ...params
                \},";
        }

        my $service = "export async function $funcname(params) {
        return request(`\${API_URL}/api/$submodelName/$funcname/$serviceparam`, {
      method: '$_->{'method'}',$bodypart
                   });
            }\n
                ";

        $requestContent .= "export function request$funcname(props $reqfunArguments) {
        const {dispatch} = props
            const payload = {
        $payloadmap}

        dispatch({
      type: '$submodelName/$funcname',
        payload: payload
             })
            }\n\n";
        $effects .= $effect;
        $variables .= $var;
        $variables .= ",\n";

        $serviceContent .= $service;
        # push (@effects, $effect);
        # push (@variables, $var);
    }
    $modelContent .= "} from '../../services/$modelName/$submodelName';\n\n";

    $modelContent .= "export default {
  namespace: '$submodelName',
    state: {
    $variables
  },";

    $modelContent .= "
    effects: {
    $effects
  },
      ";

    $modelContent .= "

    reducers: {
    update(state, payload)
    {
    return {
    ...state,
        ...payload.payload
    }
    }
  }
};\n";
    say "model---------------------";
    writeTo("model.js", $modelContent);
    say "services------------------";
    writeTo("service.js", $serviceContent);
    say "request-------------------";
    writeTo("request.js", $requestContent);
}


sub usage{
    print "parse md file to produce some js interfaces files
-f: provide the file name
-h: print this message
"
}


sub ParseError{
    my ($errmsg, $fatel) = @_;
    say $errmsg, ", line: $lineno";
    if($fatel){
        exit 1;
    }
}
