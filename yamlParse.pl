use YAML::Tiny;
use 5.010;
use warnings;
use Storable;
use Getopt::Long;
use Data::Dumper;
use Text::Balanced qw/extract_multiple extract_bracketed/;

# All use utf8; does is tell Perl the source code is encoded using UTF-8. You need to tell Perl how to encode your text:
use utf8;
use open ':std', ':encoding(UTF-8)';

require "util.pl";

use constant {
    RESVALUE => 0,
    RESSTRING => 1,
    RESOBJECT => 2,
    RESARRAY => 3,
};

my $file2parse = '';
my $request_prefix="/api";
my $modelName = '';
my $help=0;

my @iflist = ();

GetOptions( 'f=s' => \ $file2parse
            , 'm=s' => \ $modelName
            , 'h' => \ $help
    );

if ($help){
    usage();
    exit;
}

if(length($modelName) == 0 or length($file2parse) == 0){
   say "filename and module name are required" ;
   exit;
}

# Open the config
my $yaml = YAML::Tiny->read( $file2parse );

# Get a reference to the first document
my $config = $yaml->[0];
my $definitions = $config->{definitions};
my $moduleName = $config->{basePath};

print "module: $moduleName\n";

my $paths = $config->{paths};

my $mockContent = "export default \{\n";
for (keys %$paths){
    print ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>path: $_\n";
    my %interface=();
    my $reqpath=$_;

    my $postOrGetHash = $paths->{$_};
    for(keys %$postOrGetHash){
        print ("$_\n");

        my $method=lc $_;
        if($method eq "get"){
            ( $reqpath ) = $reqpath =~ /(.*)\{.*/;
        }
        $interface{'reqpath'} = $reqpath;
        my $funcname = fileName($reqpath);
        $interface{'method'} = $method;
        $interface{'func'} = $funcname;

        # params of http request
        my $requestDetail = $postOrGetHash->{$_};
        my $parametersArray = $requestDetail->{parameters};
        #print Dumper(\$parametersArray);
        my @params = ();
        my $i=0;
        for(@$parametersArray){
            say $parametersArray->[$i];
            my $parameterHash = $parametersArray->[$i];
            # parameter hash has keys: in, name, type, schema...
            # print Dumper(\$parameterHash);
            say $parameterHash->{type};
            if($parameterHash->{type} eq "object"){
                # find schema
                say $parameterHash->{schema}->{'$ref'};
                my $schemaPath=$parameterHash->{schema}->{'$ref'};
                $schemaPath =~ s|/$||;
                my ($schemaName) = $schemaPath =~ /\/([a-zA-Z0-9_]+$)/;
                say $schemaName;
                @params = parseSchema ($definitions->{$schemaName});

            }else{
                my %param=();
                $param{name}=$parameterHash->{name};
                $param{type}=$parameterHash->{type};
                push(@params, \%param);
            }
            $i++;
        }
        $interface{'params'} = \@params;
        push(@iflist, \%interface);


        print ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>parse response\n";
        my $response = $requestDetail->{responses};
        say "parse responses";
        my $responseDetail = $response->{200}->{schema}->{allOf};
        # print Dumper(\$responseDetail);
        my ($restype, $responseContent) = parseResData(@$responseDetail[1]);

        $mockContent .= "\'$method $request_prefix$reqpath\':\n";
        $mockContent .= '{"success": true,"code": 200,"message": null,"messageDetail": null,"throwable": null,
    "data":';
        if( $restype == RESOBJECT ){
           $mockContent .= '{';
        }elsif($restype == RESARRAY){
            $mockContent .= '[{';
        }

        $mockContent .= "\n$responseContent\n";
        if( $restype == RESOBJECT ){
           $mockContent .= '}';
        }elsif($restype == RESARRAY){
            $mockContent .= '}]';
        }
        $mockContent .= "\n},\n";
        $interface{'datatype'} = $restype;
    }
}
$mockContent = "$mockContent\n\}";
say "------------------------------mock\n";
writeTo("mock.js", $mockContent);

generateJSScript();
sub generateJSScript{
    # models
    my $effects = '';
    my $variables = '';
    my $services = '';
    my $modelContent = "import {\n";
    my $serviceContent = "import request from '../../utils/oauthFetch';\n\n";
    my $requestContent ='';

    # say "|||||||||||";
    # print Dumper(\@iflist);
    # say "|||||||||||";
    foreach (@iflist){
        my $funcname = $_->{'func'};
        my $reqpath = $_->{'reqpath'};
        my $varname = $funcname . 'Data ';
        my ($tmpname) = $varname =~ /[gsSG]et(.*)/;
        if( $tmpname ){
            $varname = $tmpname;
        }
        $varname = lcfirst($varname);
        $modelContent .= $funcname;
        $modelContent .= ",\n";

        my $var = $varname . ':' . defvalue($_->{'datatype'});
        my $effect = "  *$funcname({payload}, { call, put }) {
        const response = yield call($funcname, payload);
        if(response&&response.success&&response.data){
        yield put({
      type: 'update',
        payload: response.data

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
                # print Dumper(\$_);
                my $paramName =  $_->{name};
                say $httpmetohd;
                if ($httpmetohd =~ /get/){
                    $serviceparam .= "\${params.$paramName}/";
                }
                $reqfunArguments .= " $_,";
                $payloadmap .= "$_,\n";
            }

            # trim the last one ','
            $reqfunArguments =~ s/(.+),$/$1/;
            if ($reqfunArguments){
                $reqfunArguments = ','.$reqfunArguments;
            }
        }

        if ($_->{'method'} =~ /post/){
            $bodypart .= "\n    body: \{
            ...params
                \},";
        }

        my $service = "export async function $funcname(params) {
        return request(`\${API_URL}$request_prefix$reqpath/$serviceparam`, {
          method: '$_->{'method'}',$bodypart
                   });
            }\n
                ";

        $requestContent .= "export function request$funcname(props $reqfunArguments) {
        const {dispatch} = props
            const payload = {
        $payloadmap}

        dispatch({
      type: '$modelName/$funcname',
        payload
             })
            }\n\n";
        $effects .= $effect;
        $variables .= $var;
        $variables .= ",\n";

        $serviceContent .= $service;
        # push (@effects, $effect);
        # push (@variables, $var);
    }

    # if ((length($modelName) > 0) && ( $modelName !~ /\/$/ )){
    #     $modelName .= "/";
    # }

    $modelContent .= "} from '../../services/$modelName/$modelName';\n\n";

    $modelContent .= "export default {
  namespace: '$modelName',
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

sub parseResData{
    my ($in) = @_;
    my $datatype = 0;
    my $responseContent = '';
    # print Dumper(\$in);
    # $VAR1 = \{
    #         'type' => 'object',
    #         'properties' => {
    #                         'data' => {
    #                                   '$ref' => '#/definitions/ManagementServer'
    #                                 }
    #                       }
    #       };


    # get properties
    $dataDetail = $in->{properties}->{data};
    if(!$dataDetail){
        say "error........";
        exit;
    }
    say $dataDetail;

    if(!$dataDetail->{type}){
        say "not exist type info, default as object";
        $datatype = RESOBJECT;
    }
    else{
        if ($dataDetail->{type} eq "object"){
            $datatype = RESOBJECT;
        }elsif($dataDetail->{type} eq "array"){
            $datatype = RESARRAY;
        }elsif($dataDetail->{type} eq "string"){
            $datatype = RESSTRING;
        }else{
            say "error ...........";
            exit;
        }
    }
    # say "datatype: $datatype";

    my $responseData= $dataDetail;

    if($dataDetail->{items}){
        $responseData= $dataDetail->{items} ;
    }

    print "responseData: ";
    print Dumper(\$responseData);

    my $responseDataRef = $responseData->{'$ref'};
    if($responseDataRef){
        $responseContent = parseResContent(fileName($responseDataRef));
    }else{
        print "response ref not exist";
        $responseContent = $responseData->{type};
    }
    say "responseContent>>>>>>>>>>>>>>>>$responseContent";

    # print Dumper(\$dataDetail);
    # $VAR1 = \{
    #         'type' => 'array',
    #         'items' => {
    #                    '$ref' => '#/definitions/MgmtInfoTree'
    #                  }
    #       };


    # $VAR1 = \{
    #         'type' => 'string'
    #       };

    return ($datatype, $responseContent);
}

sub parseResContent{
    my ($in) = @_;
    say ">>>>>>>>>>>parse schema: $in";
    if(!$in){
        say "parseResContent error........";
        exit;
    }
    my $properties = $definitions->{$in}->{properties};
    my $demoData;
    for(keys $properties){
        $demoData .= "\"$_\": $properties->{$_}->{example}";
    }
    return $demoData;
}

sub parseSchema{
    my ($in) = @_;
    if(!$in){
        say "parseSchema error........";
        exit;
    }
    my $properties=$in->{properties};
    my @params=();
    for(keys $properties){
        my %param=();
        $param{name}=$_;
        $param{type}=$properties->{$_}->{type};
        push(@params, \%param);
    }
    # print Dumper(\@params);
    # return [{name, type},]
    return @params;
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

sub usage{
    print "parse md file to produce some js interfaces files
-f: provide the file name
-h: print this message
"
}
