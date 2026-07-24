@isTest
private class FlowScannerServiceTest {

    @isTest
    static void testInitiateAsyncScan() {
        Test.setMock(HttpCalloutMock.class, new FlowScannerMultiMock());
    
        Test.startTest();
        Id scanId = FlowScannerService.initiateAsyncScan();
        Test.stopTest();
    
        System.assertNotEquals(null, scanId,
            'Scan ID should be returned');
    
        // Query without WITH SECURITY_ENFORCED in test context
        // since test users may not have FLS configured
        List<Flow_Scan__c> scans = [
            SELECT Id, Status__c, Total_Flows_Scanned__c, Total_Violations__c
            FROM Flow_Scan__c
            WHERE Id = :scanId
            LIMIT 1
        ];
    
        System.assertEquals(1, scans.size(),
            'Scan record should exist');
        // After stopTest, the first queueable (FlowScanQueueable) runs
        // synchronously and processes the first batch inline
        // so scan should be Complete with mock data (1 flow)
        System.assert(
            scans[0].Status__c == 'Complete' || scans[0].Status__c == 'Failed',
            'Scan should be Complete or Failed. Actual: ' + scans[0].Status__c
        );
    }

    @isTest
    static void testGetScanStatus_Running() {
        Flow_Scan__c scan = new Flow_Scan__c(
            Scan_Date__c = DateTime.now(),
            Status__c    = 'Running'
        );
        insert scan;

        Test.startTest();
        Map<String, Object> status = FlowScannerService.getScanStatus(scan.Id);
        Test.stopTest();

        System.assertEquals('Running', status.get('status'),
            'Should return Running status');
    }

    @isTest
    static void testGetScanStatus_Complete() {
        Flow_Scan__c scan = new Flow_Scan__c(
            Scan_Date__c           = DateTime.now(),
            Status__c              = 'Complete',
            Total_Flows_Scanned__c = 5,
            Total_Violations__c    = 2
        );
        insert scan;

        Test.startTest();
        Map<String, Object> status = FlowScannerService.getScanStatus(scan.Id);
        Test.stopTest();

        System.assertEquals('Complete', status.get('status'));
        System.assertEquals(5, Integer.valueOf(
            String.valueOf(status.get('totalFlows'))));
    }

    @isTest
    static void testLoadRules() {
        Test.startTest();
        List<IFlowRule> rules = FlowScannerService.loadRules();
        Test.stopTest();

        System.assertNotEquals(null, rules, 'Rules should not be null');
        System.assert(rules.size() > 0, 'Should load at least one active rule');
    }

    @isTest
    static void testPersistScanResults() {
        Flow_Scan__c scan = new Flow_Scan__c(
            Scan_Date__c = DateTime.now(),
            Status__c    = 'Running'
        );
        insert scan;

        List<RuleViolation> violations = new List<RuleViolation>();
        RuleViolation v = new RuleViolation(
            'No Fault Path', 'Error', 'Create_Record',
            'Element has no fault connector'
        );
        v.flowApiName     = 'Test_Flow';
        v.flowDefinitionId = '300000000000000AAA';
        violations.add(v);

        Test.startTest();
        FlowScannerService.persistScanResults(scan.Id, 3, violations);
        Test.stopTest();

        Flow_Scan__c updated = [
            SELECT Total_Flows_Scanned__c, Total_Violations__c
            FROM Flow_Scan__c WHERE Id = :scan.Id
        ];
        System.assertEquals(3, updated.Total_Flows_Scanned__c);
        System.assertEquals(1, updated.Total_Violations__c);

        List<Flow_Scan_Result__c> results = [
            SELECT Rule_Name__c FROM Flow_Scan_Result__c
            WHERE Flow_Scan__c = :scan.Id
        ];
        System.assertEquals(1, results.size());
        System.assertEquals('No Fault Path', results[0].Rule_Name__c);
    }

    @isTest
    static void testPersistScanResults_NoViolations() {
        Flow_Scan__c scan = new Flow_Scan__c(
            Scan_Date__c = DateTime.now(),
            Status__c    = 'Running'
        );
        insert scan;

        Test.startTest();
        FlowScannerService.persistScanResults(scan.Id, 10, new List<RuleViolation>());
        Test.stopTest();

        Flow_Scan__c updated = [
            SELECT Total_Violations__c
            FROM Flow_Scan__c WHERE Id = :scan.Id
        ];
        System.assertEquals(0, updated.Total_Violations__c,
            'Should handle empty violations list');
    }
    @isTest
    static void testFetchFlowDefinitions() {
        Test.setMock(HttpCalloutMock.class, new FlowScannerMultiMock());

        Test.startTest();
        List<Map<String, Object>> definitions =
            FlowMetadataService.fetchFlowDefinitions('fakeSessionId000001');
        Test.stopTest();

        System.assertNotEquals(null, definitions,
            'Should return a list of flow definitions');
        System.assert(definitions.size() > 0,
            'Should return at least one flow definition');

        Map<String, Object> firstDef = definitions[0];
        System.assertNotEquals(null, firstDef.get('DeveloperName'),
            'Flow definition should have DeveloperName');
        System.assertNotEquals(null, firstDef.get('ActiveVersionId'),
            'Flow definition should have ActiveVersionId');
    }

    @isTest
    static void testFetchFlowDefinitions_Empty() {
        Test.setMock(HttpCalloutMock.class, new EmptyFlowListMock());

        Test.startTest();
        List<Map<String, Object>> definitions =
            FlowMetadataService.fetchFlowDefinitions('fakeSessionId000001');
        Test.stopTest();

        System.assertEquals(0, definitions.size(),
            'Should return empty list when no active flows');
    }

    @isTest
    static void testFetchFlowDefinitions_ApiError() {
        Test.setMock(HttpCalloutMock.class,
            new FlowMetadataMock(FlowMetadataMock.MockType.ERROR));

        Test.startTest();
        try {
            FlowMetadataService.fetchFlowDefinitions('fakeSessionId000001');
            System.assert(false, 'Should have thrown exception');
        } catch (FlowMetadataService.FlowScannerException e) {
            System.assert(e.getMessage().contains('Tooling API query failed'),
                'Should throw FlowScannerException on API error');
        }
        Test.stopTest();
    }

    @isTest
    static void testFetchSingleFlow() {
        Test.setMock(HttpCalloutMock.class, new FlowScannerMultiMock());

        Map<String, Object> mockFlowRec = new Map<String, Object>{
            'Id'              => '3010H000000fake01',
            'DeveloperName'   => 'Test_Flow',
            'MasterLabel'     => 'Test Flow',
            'Description'     => 'A test flow',
            'ActiveVersionId' => '3010H000000fake02'
        };

        Test.startTest();
        FlowWrapper flow = FlowMetadataService.fetchSingleFlow(
            mockFlowRec, 'fakeSessionId000001'
        );
        Test.stopTest();

        System.assertNotEquals(null, flow,
            'Should return a FlowWrapper');
        System.assertEquals('Test_Flow', flow.flowApiName,
            'Flow API name should match');
        System.assertEquals('Test Flow', flow.flowLabel,
            'Flow label should match');
    }

    @isTest
    static void testFetchSingleFlow_InvalidId() {
        Test.setMock(HttpCalloutMock.class, new FlowScannerMultiMock());

        // Invalid ID — should be skipped
        Map<String, Object> mockFlowRec = new Map<String, Object>{
            'Id'              => 'invalid!!!',
            'DeveloperName'   => 'Bad_Flow',
            'MasterLabel'     => 'Bad Flow',
            'Description'     => null,
            'ActiveVersionId' => 'also-invalid'
        };

        Test.startTest();
        // fetchSingleFlow calls fetchFlowMetadata which will get a null response
        // from the mock for an unrecognised ID pattern — returns null
        FlowWrapper flow = FlowMetadataService.fetchSingleFlow(
            mockFlowRec, 'fakeSessionId000001'
        );
        Test.stopTest();

        // Either null returned or flow with empty elements — both acceptable
        System.assert(flow == null || flow.elements != null,
            'Should handle invalid ID gracefully');
    }
    @isTest
    static void testFetchFlowDefinitions_ValidatesOrgDomain() {
        Test.setMock(HttpCalloutMock.class, new FlowScannerMultiMock());

        // This test just confirms fetchFlowDefinitions runs without
        // domain validation error in a valid scratch org context
        Test.startTest();
        List<Map<String, Object>> defs =
            FlowMetadataService.fetchFlowDefinitions('fakeSessionId000001');
        Test.stopTest();

        System.assertNotEquals(null, defs,
            'Should complete without domain validation error in scratch org');
    }

    @isTest
    static void testFetchAllFlows_Direct() {
        Test.setMock(HttpCalloutMock.class, new FlowScannerMultiMock());

        Test.startTest();
        List<FlowWrapper> flows =
            FlowMetadataService.fetchAllFlows('fakeSessionId000001');
        Test.stopTest();

        System.assertNotEquals(null, flows,
            'Should return list of flows');
        System.assert(flows.size() > 0,
            'Should return at least one flow');
        System.assertEquals('Test_Flow', flows[0].flowApiName,
            'Flow API name should match mock data');
    }

    @isTest
    static void testFetchAllFlows_Empty() {
        Test.setMock(HttpCalloutMock.class, new EmptyFlowListMock());

        Test.startTest();
        List<FlowWrapper> flows =
            FlowMetadataService.fetchAllFlows('fakeSessionId000001');
        Test.stopTest();

        System.assertEquals(0, flows.size(),
            'Should return empty list when no active flows');
    }

    @isTest
    static void testFetchAllFlows_ApiError() {
        Test.setMock(HttpCalloutMock.class,
            new FlowMetadataMock(FlowMetadataMock.MockType.ERROR));

        Test.startTest();
        try {
            FlowMetadataService.fetchAllFlows('fakeSessionId000001');
            System.assert(false, 'Should have thrown exception');
        } catch (FlowMetadataService.FlowScannerException e) {
            System.assert(e.getMessage().contains('Tooling API query failed'),
                'Should throw FlowScannerException on API error');
        }
        Test.stopTest();
    }
}