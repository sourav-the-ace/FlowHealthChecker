@isTest
public class FlowScannerMultiMock implements HttpCalloutMock {

    private Integer callCount = 0;

    public HTTPResponse respond(HTTPRequest req) {
        callCount++;
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(200);

        String endpoint = req.getEndpoint();

        if (endpoint.contains('FlowDefinition')) {
            res.setBody(
                '{"totalSize":1,"done":true,"records":[{'
                + '"Id":"3010H000000fake001",'
                + '"DeveloperName":"Test_Flow",'
                + '"MasterLabel":"Test Flow",'
                + '"Description":null,'
                + '"ActiveVersionId":"3010H000000fake002"'
                + '}]}'
            );
        } else if (endpoint.contains('tooling/sobjects/Flow/')) {
            res.setBody(
                '{"Id":"3010H000000fake002","Metadata":{'
                + '"processType":"AutoLaunchedFlow",'
                + '"loops":[{"name":"TestLoop","nextValueConnector":{"targetReference":"Create_In_Loop"}}],'
                + '"recordCreates":[{"name":"Create_In_Loop","faultConnector":null}],'
                + '"recordUpdates":[{"name":"Update_No_Fault","faultConnector":null}],'
                + '"actionCalls":[],"recordDeletes":[],"recordLookups":[],'
                + '"apexPluginCalls":[],"assignments":[],"decisions":[]}}'
            );
        } else {
            res.setBody('{}');
        }
        return res;
    }
    @isTest
    static void testQueueableRuns() {
        Test.setMock(HttpCalloutMock.class, new FlowScannerMultiMock());
    
        Flow_Scan__c scan = new Flow_Scan__c(
            Scan_Date__c = DateTime.now(),
            Status__c    = 'Pending'
        );
        insert scan;
    
        Test.startTest();
        System.enqueueJob(new FlowScanQueueable(scan.Id));
        Test.stopTest();
    
        Flow_Scan__c result = [
            SELECT Status__c, Total_Flows_Scanned__c, Error_Message__c
            FROM Flow_Scan__c WHERE Id = :scan.Id
        ];
        System.assertEquals('Complete', result.Status__c,
            'Queueable should mark scan Complete. Error: ' + result.Error_Message__c
        );
        System.assertEquals(1, result.Total_Flows_Scanned__c,
            'Should have scanned 1 flow');
    }
}