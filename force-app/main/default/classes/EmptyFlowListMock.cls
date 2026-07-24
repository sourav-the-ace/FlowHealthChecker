@isTest
public class EmptyFlowListMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(200);
        res.setBody('{"totalSize":0,"done":true,"records":[]}');
        return res;
    }
}