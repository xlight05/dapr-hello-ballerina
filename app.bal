import ballerina/http;
import ballerina/os;
import ballerina/log;

string daprPortStr = os:getEnv("DAPR_HTTP_PORT");
string daprPort = daprPortStr is "" ? "3500" : daprPortStr;
const stateStoreName = "statestore";
http:Client clientEP = check new ("http://localhost:" + daprPort + "/v1.0/state/" + stateStoreName);
http:Client testEp = check new ("http://localhost:9091/test");
service http:Service / on new http:Listener(3000) {

    resource function get 'order() returns json|error {
        json payload = check clientEP->get("/order", targetType = json);
        return payload;
    }

    resource function post neworder(http:Request req) returns json|error {
        json payload = check req.getJsonPayload();
        json data = check payload.data;
        int orderId = check data.orderId;
        log:printInfo("Got a new order! Order ID: " + orderId.toString());

        json state = [{
            key: "order",
            value: data
        }];
        
        http:Response resp = check clientEP->post("", state);
        if (resp.statusCode == 204) {
            json success = ("Successfully persisted state.");
            return success;
        }
                log:printInfo(resp.statusCode.toString());
        json failure = ("An error occured.");
        return failure;
    }
}
