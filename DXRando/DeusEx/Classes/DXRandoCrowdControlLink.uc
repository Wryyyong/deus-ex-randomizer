//=============================================================================
// DXRandoCrowdControlLink.
//=============================================================================
class DXRandoCrowdControlLink extends TcpLink transient;

var string crowd_control_addr;

var DXRCrowdControl ccModule;
var DXRCrowdControlEffects ccEffects;

var DataStorage datastorage;
var transient DXRando dxr;
var int ListenPort;
var IpAddr addr;

var int ticker;

var bool anon;

var int reconnectTimer;
const ReconDefault = 5;

var string pendingMsg;

const Success = 0;
const Failed = 1;
const NotAvail = 2;
const TempFail = 3;

const CrowdControlPort = 43384;


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////                                  CROWD CONTROL FRAMEWORK                                                 ////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////


function Init( DXRando tdxr, DXRCrowdControl cc, string addr, bool anonymous)
{
    dxr = tdxr;
    ccModule = cc;
    crowd_control_addr = addr;
    anon = anonymous;

    //Initialize the effect class
    ccEffects = Spawn(class'DXRCrowdControlEffects');
    ccEffects.Init(self,dxr);

    //Initialize the pending message buffer
    pendingMsg = "";

    //Initialize the ticker
    ticker = 0;

    Resolve(crowd_control_addr);

    reconnectTimer = ReconDefault;
    SetTimer(0.1,True);

}

function Timer() {

    ticker++;
    if (IsConnected()) {
        ManualReceiveBinary();
    }

    ccEffects.ContinuousUpdates();

    if (ticker%10 != 0) {
        return;
    }
    //Everything below here runs once a second

    if (!IsConnected()) {
        reconnectTimer-=1;
        if (reconnectTimer <= 0){
            Resolve(crowd_control_addr);
        }
    }

    ccEffects.PeriodicUpdates();
}


function bool isCrowdControl(string msg) {
    local string tmp;
    //Check to see if it looks like it has the right fields in it

    //id field
    if (InStr(msg,"id")==-1){
        //PlayerMessage("Doesn't have id");
        return False;
    }

    //code field
    if (InStr(msg,"code")==-1){
        //PlayerMessage("Doesn't have code");
        return False;
    }
    //viewer field
    if (InStr(msg,"viewer")==-1){
        //PlayerMessage("Doesn't have viewer");
        return False;
    }

    return True;
}

function sendReply(int id, int status) {
    local string resp;
    local byte respbyte[255];
    local int i;

    resp = "{\"id\":"$id$",\"status\":"$status$"}";

    for (i=0;i<Len(resp);i++){
        respbyte[i]=Asc(Mid(resp,i,1));
    }

    //PlayerMessage(resp);
    SendBinary(Len(resp)+1,respbyte);
}


function handleMessage(string msg) {

    local int id,type;
    local string code,viewer;
    local string param[5];

    local int result;

    local Json jmsg;
    local int i;

    if (isCrowdControl(msg)) {
        jmsg = class'Json'.static.parse(Level, msg);
        code = jmsg.get("code");
        viewer = jmsg.get("viewer");
        id = int(jmsg.get("id"));
        type = int(jmsg.get("type"));
        // maybe a little cleaner than using get_vals and having to worry about matching the array sizes?
        for(i=0; i<ArrayCount(param); i++) {
            param[i] = jmsg.get("parameters", i);
        }

        //Streamers may not want names to show up in game
        //so that they can avoid troll names, etc
        if (anon) {
            viewer = "Crowd Control";
        }
        result = ccEffects.doCrowdControlEvent(code,param,viewer,type);

        if (result == Success) {
            ccModule.IncHandledEffects();
        }

        sendReply(id,result);

    } else {
        err("Got a weird message: "$msg);
    }

}

//I cannot believe I had to manually write my own version of ReceivedBinary
function ManualReceiveBinary() {
    local byte B[255]; //I have to use a 255 length array even if I only want to read 1
    local int count,i;
    //PlayerMessage("Manually reading, have "$DataPending$" bytes pending");

    if (DataPending!=0) {
        count = ReadBinary(255,B);
        for (i = 0; i < count; i++) {
            if (B[i] == 0) {
                if (Len(pendingMsg)>0){
                    //PlayerMessage(pendingMsg);
                    handleMessage(pendingMsg);
                }
                pendingMsg="";
            } else {
                pendingMsg = pendingMsg $ Chr(B[i]);
                //PlayerMessage("ReceivedBinary: " $ B[i]);
            }
        }
    }

}

event Opened(){
    PlayerMessage("Crowd Control connection opened");
}

event Closed(){
    PlayerMessage("Crowd Control connection closed");
    ListenPort = 0;
    reconnectTimer = ReconDefault;
}

event Destroyed(){
    Close();
    Super.Destroyed();
}

function Resolved( IpAddr Addr )
{
    if (ListenPort == 0) {
        ListenPort=BindPort();
        if (ListenPort==0){
            err("Failed to bind port for Crowd Control");
            reconnectTimer = ReconDefault;
            return;
        }
    }

    Addr.port=CrowdControlPort;
    if (False==Open(Addr)){
        err("Could not connect to Crowd Control client");
        reconnectTimer = ReconDefault;
        return;

    }

    //Using manual binary reading, which is handled by ManualReceiveBinary()
    //This means that we can handle if multiple crowd control messages come in
    //between reads.
    LinkMode=MODE_Binary;
    ReceiveMode = RMODE_Manual;

}
function ResolveFailed()
{
    err("Could not resolve Crowd Control address");
    reconnectTimer = ReconDefault;
}




//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////                                        UTILITY FUNCTIONS                                                 ////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////


simulated final function #var PlayerPawn  player()
{
    return dxr.flags.player();
}

function PlayerMessage(string msg)
{
    log(Self$": "$msg);
    class'DXRTelemetry'.static.SendLog(dxr, Self, "INFO", msg);
    player().ClientMessage(msg, 'CrowdControl', true);
}

function err(string msg)
{
    log(Self$": ERROR: "$msg);
    class'DXRTelemetry'.static.SendLog(dxr, Self, "ERROR", msg);
    player().ClientMessage(msg, 'ERROR', true);
}

function info(string msg)
{
    log(Self$": INFO: "$msg);
    class'DXRTelemetry'.static.SendLog(dxr, Self, "INFO", msg);
}

function SplitString(string src, string divider, out string parts[8])
{
    local int i, c;

    parts[0] = src;
    for(i=0; i+1<ArrayCount(parts); i++) {
        c = InStr(parts[i], divider);
        if( c == -1 ) {
            return;
        }
        parts[i+1] = Mid(parts[i], c+1);
        parts[i] = Left(parts[i], c);
    }
}






//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////                                           TEST FRAMEWORK                                                 ////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////


function RunTests(DXRCrowdControl m)
{
    local int i;
    local string msg;
    local string params[5];
    local string words[8];
    local Json j;

    SplitString("add_aug_aqualung", "_", words);
    m.teststring(words[0], "add", "SplitString");
    m.teststring(words[1], "aug", "SplitString");
    m.teststring(words[2], "aqualung", "SplitString");
    m.teststring(words[3], "", "SplitString");

    msg="";
    m.testbool( isCrowdControl(msg), false, "isCrowdControl "$msg);

    msg="{}";
    m.testbool( isCrowdControl(msg), false, "isCrowdControl "$msg);

    msg=" \"key\": \"value\" ";
    j = class'Json'.static.parse(Level, msg);
    m.teststring(j.get("key"), "", "did not parse invalid json");
    m.teststring(j.JsonStripSpaces(msg), "", "invalid json completely stripped");
    m.teststring(j.JsonStripSpaces(" { " $ msg), "", "invalid json completely stripped");
    m.teststring(j.JsonStripSpaces(msg $ " } "), "", "invalid json completely stripped");

    m.teststring(j.JsonStripSpaces(" { } "), "{}", "JsonStripSpaces");

    msg=" { \"key\": \"value \\\"{}[]()\\\"\" } ";
    j = class'Json'.static.parse(Level, msg);
    m.teststring(j.get("key"), "value \"{}[]()\"", "did parse valid json");

    msg="{\"id\":3,\"code\":\"disable_jump\",\"targets\":[{\"id\":\"1234\",\"name\":\"dxrandotest\",\"avatar\":\"\"}],\"viewer\":\"dxrandotest\",\"type\":1}";
    m.testbool( isCrowdControl(msg), true, "isCrowdControl "$msg);
    _TestMsg(m,msg,3,1,"disable_jump","dxrandotest",params);

    // test multiple payloads, Crowd Control always puts a \0 between them so this isn't an issue, but still good to be safe
    msg=" {\"id\":3,\"code\":\"disable_jump\",\"viewer\":\"dxrandotest\",\"type\":1}{\"parameters\":[1,2,3],\"code\":\"fail\"} ";
    m.testbool( isCrowdControl(msg), true, "isCrowdControl "$msg);
    _TestMsg(m,msg,3,1,"disable_jump","dxrandotest",params);

    TestMsg(m, 123, 1, "kill", "die4ever", params);
    TestMsg(m, 123, 1, "test with spaces", "die4ever", params);
    TestMsg(m, 123, 1, "test:with:colons", "die4ever", params);
    TestMsg(m, 123, 1, "test,with,commas", "die4ever", params);
    params[0] = "parameter test";
    TestMsg(m, 123, 1, "kill", "die4ever", params);
    params[0] = "g_scrambler";
    TestMsg(m, 123, 1, "drop_grenade", "die4ever", params);
    params[0] = "g_scrambler";
    params[1] = "10";
    TestMsg(m, 123, 1, "drop_grenade", "die4ever", params);

    TestMsg(m, 123, 1, "drop_grenade", "-(:die[4]ever{dm}:)-", params);

    //Need to do more work to validate escaped characters
    //TestMsg(m, 123, 1, "test\\\\with\\\\escaped\\\\backslashes", "die4ever", ""); //Note that we have to double escape so that the end result is a single escaped backslash

    /*msg = "{ \"testkeyname\": 1 ";
    for(i=0; i<90; i++) {
        msg = msg $ " , \"testlongkeyname-"$i$"\": [1,2,3,4,5,6,7,8,9] ";
    }
    msg = msg $ "}";
    log("TIME: start long json parses 90 arrays");
    for(i=0; i<50; i++)
        j = class'Json'.static.parse(Level, msg);
    log("TIME: end long json parses 90 arrays");*/


    msg = "{ \"testkeyname\": 1 ";
    for(i=0; i<90; i++) {
        msg = msg $ " , \"testlongkeyname-"$i$"\": [\"1\",\"2\",\"3\",\"4\",\"5\",\"6\",\"7\",\"8\",\"9\"] ";
    }
    msg = msg $ "}";
    log("TIME: start long json parses 90 arrays with quotes");
    for(i=0; i<50; i++)
        j = class'Json'.static.parse(Level, msg);
    log("TIME: end long json parses 90 arrays with quotes");


    /*msg = "{ \"test really long key name\": \"1\" ";
    for(i=0; Len(msg)<4000; i++) {
        msg = msg $ " , \"test long key name-"$i$"\": \"[1, 2, 3,4, 5, 6, 7, 8, 9]\" ";
        if(i>=99) m.test(false, "oops");
    }
    msg = msg $ "}";
    log("TIME: start long json parses strings");
    for(i=0; i<50; i++)
        j = class'Json'.static.parse(Level, msg);
    log("TIME: end long json parses strings");*/

    /*msg = "{ \"test really long key name\": \"1\" ";
    for(i=0; i<90; i++) {
        msg = msg $ " , \"test long key name-"$i$"\": \"[1, 2, 3,4, 5, 6, 7, 8, 9]\" ";
        if(i>=99) m.test(false, "oops");
    }
    msg = msg $ "}";
    log("TIME: start long json parses 90 strings");
    for(i=0; i<50; i++)
        j = class'Json'.static.parse(Level, msg);
    log("TIME: end long json parses 90 strings");*/
}


function int TestJsonField(DXRCrowdControl m, Json jmsg, string key, coerce string expected)
{
    local int len;
    m.test(jmsg.count() < jmsg.max_count(), "jmsg.count() < jmsg.max_count()");
    len = jmsg.get_vals_count(key);
    if(expected == "" && len == 0) {
        m.test(true, "TestJsonField "$key$" correctly missing");
    } else {
        m.test(len > 0, "je.valCount > 0");
        m.test(len < jmsg.max_values(), "je.valCount < ArrayCount(je.value)");
        m.teststring(jmsg.get(key, 0), expected, "TestJsonField " $ key);
    }
    return len;
}

function _TestMsg(DXRCrowdControl m, string msg, int id, int type, string code, string viewer, string params[5])
{
    local int p;
    local Json jmsg;

    m.testbool( isCrowdControl(msg), true, "isCrowdControl: "$msg);

    jmsg = class'Json'.static.parse(Level, msg);
    m.testint(TestJsonField(m, jmsg, "code", code), 1, "got 1 code");
    m.testint(TestJsonField(m, jmsg, "viewer", viewer), 1, "got 1 viewer");
    m.testint(TestJsonField(m, jmsg, "id", id), 1, "got 1 id");
    m.testint(TestJsonField(m, jmsg, "type", type), 1, "got 1 type");


    TestJsonField(m, jmsg, "parameters", params[0]);
    for(p=0; p<ArrayCount(params); p++) {
        m.teststring(jmsg.get("parameters", p), params[p], "param "$p);
    }
}

function string BuildParamsString(string params[5])
{
    local int i, num_params;
    local string params_string;

    for(i=0; i < ArrayCount(params); i++) {
        if( params[i] != "" ) num_params++;
    }

    if( num_params > 1 ) {
        params_string = "[";
        for(i=0; i < ArrayCount(params); i++) {
            if( params[i] != "" )
                params_string = params_string $ params[i] $ ",";
        }
        params_string = Left(params_string, Len(params_string)-1);//trim trailing comma
        params_string = params_string $ "]";
    }
    else if ( num_params <= 1 )
        params_string = "\""$params[0]$"\"";

    return params_string;
}

function TestMsg(DXRCrowdControl m, int id, int type, string code, string viewer, string params[5])
{
    local string msg, params_string, targets;

    params_string = BuildParamsString(params);

    msg = "{\"id\":\""$id$"\",\"code\":\""$code$"\",\"viewer\":\""$viewer$"\",\"type\":\""$type$"\",\"parameters\":"$params_string$"}";
    _TestMsg(m, msg, id, type, code, viewer, params);

    // test new targets field, in the beginning, in the middle, and at the end...
    targets = "[{\"id\":\"1234\",\"name\":\"Die4Ever\",\"avatar\":\"\"}]";
    msg = "{\"id\":\""$id$"\",\"code\":\""$code$"\",\"targets\":"$targets$",\"viewer\":\""$viewer$"\",\"type\":\""$type$"\",\"parameters\":"$params_string$"}";
    _TestMsg(m, msg, id, type, code, viewer, params);

    msg = "{\"targets\":"$targets$",\"id\":\""$id$"\",\"code\":\""$code$"\",\"viewer\":\""$viewer$"\",\"type\":\""$type$"\",\"parameters\":"$params_string$"}";
    _TestMsg(m, msg, id, type, code, viewer, params);

    msg = "{\"id\":\""$id$"\",\"code\":\""$code$"\",\"targets\":"$targets$",\"viewer\":\""$viewer$"\",\"type\":\""$type$"\",\"parameters\":"$params_string$",\"targets\":"$targets$"}";
    _TestMsg(m, msg, id, type, code, viewer, params);

    // test array of objects
    targets = "[{\"id\":\"1234\",\"name\":\"Die4Ever\",\"avatar\":\"\"},{\"name\":\"TheAstropath\"}]";
    msg = "{\"id\":\""$id$"\",\"code\":\""$code$"\",\"targets\":"$targets$",\"viewer\":\""$viewer$"\",\"type\":\""$type$"\",\"parameters\":"$params_string$",\"targets\":"$targets$"}";
    _TestMsg(m, msg, id, type, code, viewer, params);

    // test sub objects
    targets = "{\"array\":[{\"id\":\"1234\",\"name\":\"Die4Ever\",\"avatar\":\"\"},{\"name\":\"TheAstropath\"}]}";
    msg = "{\"id\":\""$id$"\",\"code\":\""$code$"\",\"targets\":"$targets$",\"viewer\":\""$viewer$"\",\"type\":\""$type$"\",\"parameters\":"$params_string$",\"targets\":"$targets$"}";
    _TestMsg(m, msg, id, type, code, viewer, params);
}


