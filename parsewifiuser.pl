#!/usr/bin/perl
#
use 5.010;
use warnings;
use Storable;
use Getopt::Long;
use Data::Dumper;
use utf8;

use constant {
    RESVALUE => 0,
    RESSTRING => 1,
    RESOBJECT => 2,
    RESARRAY => 3,
};

my $file2parse = '';
my $help=0;
my $modelName = 'experienceInsight';
my $submodelName = 'wifiuser';
GetOptions( 'f=s' => \ $file2parse
          , 'h' => \ $help
          , 'm=s' => \ $modelName
          );

if ($help){
    usage();
    exit;
}

my @iflist = ();

parseMD();
generateJSScript();

sub parseMD{
    # $file2parse is global v
    if ( -e $file2parse ){
        open ( my $in, "<:encoding(utf8)", $file2parse ) or die "$file2parse: $!";
        while (my $line = <$in>) {
            chomp $line;
            # skip comment
            if ($line =~ /^#/ or $line =~ /^-/){
                next;
            }
            $line=~ s/^\s+//;
            if (my ($httpmethod) = $line =~ /^([gGpP][a-zA-Z]+)\s/){
                my %interface=();
                my ($reqpath) = $line =~ /(\/.+$)/;
                my ($funcname) = $reqpath =~ /\/([a-zA-Z0-9_]+$)/;
                $interface{'method'} = uc $httpmethod;
                $interface{'reqpath'} = $reqpath;
                $interface{'func'} = $funcname;
                my @params = seekparam($in);
                my $restype = seekdata($in);
                $interface{'datatype'} = $restype;
                $interface{'params'} = \@params;
                push(@iflist, \%interface);
            }
        }

        # print Dumper(\@iflist);
        close $in;
    }
}

sub seekparam{
    my ($in) = @_;
    my $parambegin=0;
    my @params=();
    while( my $line = <$in> ){
        chomp $line;
        $line=~ s/^\s+|\s+$//g;
        if ($line =~ /^\}/ and $parambegin == 1){
            # print Dumper(\@params);
            return @params;
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
    while( my $line = <$in> ){
        chomp $line;
        $line=~ s/^\s+|\s+$//g;
        if ($line =~ /^\}/ and $databegin == 1){
            return $datatype;
            last;
        }
        if ($line =~ /^\"data\"/){
            # reach data section
            if ($databegin == 0){
                $databegin = 1;
            }else{
                ParseError("unexpected data section");
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
  return request(`\${API_URL}/api/wifiuser/$funcname/$serviceparam`, {
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
    # say $modelContent;
    say "services------------------";
    say $serviceContent;
    say "request-------------------";
    # say $requestContent;
}
sub usage{
    print "parse md file to produce some js interfaces files
-f: provide the file name
-h: print this message
"
}


sub ParseError{
    my ($errmsg) = @_;
    say $errmsg;
}
