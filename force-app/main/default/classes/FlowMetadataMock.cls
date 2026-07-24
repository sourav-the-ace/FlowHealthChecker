@isTest
public class FlowMetadataMock implements HttpCalloutMock {

    // Controls which response to return
    public enum MockType { FLOW_LIST, FLOW_METADATA, ERROR }
    private MockType mockType;

    public FlowMetadataMock(MockType mockType) {
        this.mockType = mockType;
    }

    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');

        if (mockType == FlowMetadataMock.MockType.ERROR)  {
            res.setStatusCode(401);
            res.setBody('[{"message":"Unauthorized","errorCode":"INVALID_SESSION_ID"}]');
            return res;
        }

        String endpoint = req.getEndpoint();

        // FlowDefinition list query
        if (endpoint.contains('FlowDefinition')) {
            res.setStatusCode(200);
            res.setBody(getFlowListResponse());
            return res;
        }

        // Individual flow metadata fetch
        if (endpoint.contains('tooling/sobjects/Flow/')) {
            res.setStatusCode(200);
            res.setBody(getFlowMetadataResponse());
            return res;
        }

        res.setStatusCode(200);
        res.setBody('{}');
        return res;
    }

    private String getFlowListResponse() {
        return '{'
            + '"totalSize": 1,'
            + '"done": true,'
            + '"records": [{'
            + '  "Id": "3010H000000fake001",'
            + '  "DeveloperName": "Test_Flow",'
            + '  "MasterLabel": "Test Flow",'
            + '  "Description": null,'
            + '  "ActiveVersionId": "3010H000000fake002"'
            + '}]'
            + '}';
    }

    private String getFlowMetadataResponse() {
        return '{'
            + '"Id": "3010H000000fake002",'
            + '"Metadata": {'
            + '  "processType": "AutoLaunchedFlow",'
            + '  "loops": [{'
            + '    "name": "TestLoop",'
            + '    "nextValueConnector": {'
            + '      "targetReference": "Create_In_Loop"'
            + '    }'
            + '  }],'
            + '  "recordCreates": [{'
            + '    "name": "Create_In_Loop",'
            + '    "faultConnector": null'
            + '  }],'
            + '  "recordUpdates": [{'
            + '    "name": "Update_No_Fault",'
            + '    "faultConnector": null'
            + '  }],'
            + '  "actionCalls": [],'
            + '  "recordDeletes": [],'
            + '  "recordLookups": [],'
            + '  "apexPluginCalls": [],'
            + '  "assignments": [],'
            + '  "decisions": []'
            + '}'
            + '}';
    }
}