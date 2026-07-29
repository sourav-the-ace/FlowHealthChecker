@isTest
private class FlowHealthCheckerControllerTest {

    @isTest
    static void testGetScanResults() {
        // Create test data
        Flow_Scan__c scan = new Flow_Scan__c(
            Scan_Date__c            = DateTime.now(),
            Total_Flows_Scanned__c  = 2,
            Total_Violations__c     = 1
        );
        insert scan;

        Flow_Scan_Result__c result = new Flow_Scan_Result__c(
            Flow_Scan__c     = scan.Id,
            Flow_API_Name__c = 'Test_Flow',
            Rule_Name__c     = 'No Fault Path',
            Severity__c      = 'Error',
            Element_Name__c  = 'Create_Record',
            Description__c   = 'Missing fault path'
        );
        insert result;

        Test.startTest();
        Map<String, Object> response =
            FlowHealthCheckerController.getScanResults(scan.Id);
        Test.stopTest();

        System.assertNotEquals(null, response, 'Response should not be null');
        System.assert(response.containsKey('scan'), 'Should contain scan key');
        System.assert(response.containsKey('results'), 'Should contain results key');

        List<Flow_Scan_Result__c> results =
            (List<Flow_Scan_Result__c>) response.get('results');
        System.assertEquals(1, results.size(), 'Should return 1 result');
        System.assertEquals('No Fault Path', results[0].Rule_Name__c);
    }

    @isTest
    static void testGetScanResultsNoViolations() {
        Flow_Scan__c scan = new Flow_Scan__c(
            Scan_Date__c           = DateTime.now(),
            Total_Flows_Scanned__c = 5,
            Total_Violations__c    = 0
        );
        insert scan;

        Test.startTest();
        Map<String, Object> response =
            FlowHealthCheckerController.getScanResults(scan.Id);
        Test.stopTest();

        List<Flow_Scan_Result__c> results =
            (List<Flow_Scan_Result__c>) response.get('results');
        System.assertEquals(0, results.size(), 
            'Should return empty results list');
    }
    @isTest
    static void testGetRules() {
        Test.startTest();
        List<Flow_Rule__mdt> rules = FlowHealthCheckerController.getRules();
        Test.stopTest();

        System.assertNotEquals(null, rules, 'Rules list should not be null');
        System.assert(rules.size() > 0, 'Should return at least one rule');

        // Verify expected fields are populated
        for (Flow_Rule__mdt r : rules) {
            System.assertNotEquals(null, r.MasterLabel, 
                'Each rule should have a label');
            System.assertNotEquals(null, r.svfhc__Severity__c, 
                'Each rule should have a severity');
        }
    }
    @isTest
    static void testGetScanResults_NoResults() {
        Flow_Scan__c scan = new Flow_Scan__c(
            Scan_Date__c           = DateTime.now(),
            Status__c              = 'Complete',
            Total_Flows_Scanned__c = 5,
            Total_Violations__c    = 0
        );
        insert scan;

        Test.startTest();
        Map<String, Object> response =
            FlowHealthCheckerController.getScanResults(scan.Id);
        Test.stopTest();

        System.assertNotEquals(null, response,
            'Response should not be null');

        Flow_Scan__c returnedScan =
            (Flow_Scan__c) response.get('scan');
        System.assertEquals('Complete', returnedScan.Status__c,
            'Status should be Complete');

        List<Flow_Scan_Result__c> results =
            (List<Flow_Scan_Result__c>) response.get('results');
        System.assertEquals(0, results.size(),
            'Should return empty results list');
    }

    @isTest
    static void testGetScanResults_MultipleViolations() {
        Flow_Scan__c scan = new Flow_Scan__c(
            Scan_Date__c           = DateTime.now(),
            Status__c              = 'Complete',
            Total_Flows_Scanned__c = 3,
            Total_Violations__c    = 3
        );
        insert scan;

        List<Flow_Scan_Result__c> results = new List<Flow_Scan_Result__c>{
            new Flow_Scan_Result__c(
                Flow_Scan__c     = scan.Id,
                Flow_API_Name__c = 'Flow_One',
                Rule_Name__c     = 'No Fault Path',
                Severity__c      = 'Error',
                Element_Name__c  = 'Create_Record',
                Description__c   = 'Missing fault path'
            ),
            new Flow_Scan_Result__c(
                Flow_Scan__c     = scan.Id,
                Flow_API_Name__c = 'Flow_Two',
                Rule_Name__c     = 'Missing Description',
                Severity__c      = 'Warning',
                Element_Name__c  = 'Flow_Two',
                Description__c   = 'No description'
            ),
            new Flow_Scan_Result__c(
                Flow_Scan__c     = scan.Id,
                Flow_API_Name__c = 'Flow_Two',
                Rule_Name__c     = 'DML In Loop',
                Severity__c      = 'Error',
                Element_Name__c  = 'Update_Record',
                Description__c   = 'DML inside loop'
            )
        };
        insert results;

        Test.startTest();
        Map<String, Object> response =
            FlowHealthCheckerController.getScanResults(scan.Id);
        Test.stopTest();

        List<Flow_Scan_Result__c> returned =
            (List<Flow_Scan_Result__c>) response.get('results');
        System.assertEquals(3, returned.size(),
            'Should return all 3 violations');
    }

    @isTest
    static void testGetRules_ReturnsList() {
        Test.startTest();
        List<Flow_Rule__mdt> rules =
            FlowHealthCheckerController.getRules();
        Test.stopTest();

        System.assertNotEquals(null, rules,
            'Rules list should not be null');
        System.assert(rules.size() > 0,
            'Should return at least one rule from Custom Metadata');

        for (Flow_Rule__mdt r : rules) {
            System.assertNotEquals(null, r.MasterLabel,
                'Each rule should have a MasterLabel');
            System.assertNotEquals(null, r.svfhc__Severity__c,
                'Each rule should have a Severity');
        }
    }

    @isTest
    static void testGetRules_SeverityOrdering() {
        Test.startTest();
        List<Flow_Rule__mdt> rules =
            FlowHealthCheckerController.getRules();
        Test.stopTest();

        // Verify rules come back ordered — Errors before Warnings
        Boolean foundWarning = false;
        for (Flow_Rule__mdt r : rules) {
            if (r.svfhc__Severity__c == 'Warning') {
                foundWarning = true;
            }
            if (foundWarning && r.svfhc__Severity__c == 'Error') {
                System.assert(false,
                    'Errors should come before Warnings in ordering');
            }
        }
        System.assert(true, 'Rules are correctly ordered');
    }

    @isTest
    static void testGetScanResults_WithFlowDefinitionId() {
        Flow_Scan__c scan = new Flow_Scan__c(
            Scan_Date__c           = DateTime.now(),
            Status__c              = 'Complete',
            Total_Flows_Scanned__c = 1,
            Total_Violations__c    = 1
        );
        insert scan;

        Flow_Scan_Result__c result = new Flow_Scan_Result__c(
            Flow_Scan__c          = scan.Id,
            Flow_API_Name__c      = 'Test_Flow',
            Rule_Name__c          = 'No Fault Path',
            Severity__c           = 'Error',
            Element_Name__c       = 'Create_Record',
            Description__c        = 'Missing fault path',
            Flow_Definition_Id__c = '3000H000000FakeAAA'
        );
        insert result;

        Test.startTest();
        Map<String, Object> response =
            FlowHealthCheckerController.getScanResults(scan.Id);
        Test.stopTest();

        List<Flow_Scan_Result__c> results =
            (List<Flow_Scan_Result__c>) response.get('results');
        System.assertEquals(1, results.size(),
            'Should return 1 result');
        System.assertEquals('3000H000000FakeAAA',
            results[0].Flow_Definition_Id__c,
            'Flow Definition ID should be returned');
    }

    @isTest
    static void testGetScanStatus_Failed() {
        Flow_Scan__c scan = new Flow_Scan__c(
            Scan_Date__c     = DateTime.now(),
            Status__c        = 'Failed',
            Error_Message__c = 'Test error message'
        );
        insert scan;

        Test.startTest();
        Map<String, Object> status =
            FlowScannerService.getScanStatus(scan.Id);
        Test.stopTest();

        System.assertEquals('Failed', status.get('status'),
            'Should return Failed status');
        System.assertEquals('Test error message',
            status.get('errorMessage'),
            'Should return error message');
    }
    @isTest
    static void testGetScanResults_PermissionCheck() {
        // Verify method runs successfully for admin user
        // (full permission check coverage via happy path)
        Flow_Scan__c scan = new Flow_Scan__c(
            Scan_Date__c           = DateTime.now(),
            Status__c              = 'Complete',
            Total_Flows_Scanned__c = 1,
            Total_Violations__c    = 0
        );
        insert scan;

        Test.startTest();
        Map<String, Object> response =
            FlowHealthCheckerController.getScanResults(scan.Id);
        Test.stopTest();

        System.assertNotEquals(null, response.get('scan'),
            'Scan should be returned for accessible user');
    }

    @isTest
    static void testGetRules_ReturnsActiveRules() {
        Test.startTest();
        List<Flow_Rule__mdt> rules = FlowHealthCheckerController.getRules();
        Test.stopTest();

        // Verify all returned rules have required fields populated
        for (Flow_Rule__mdt r : rules) {
            System.assertNotEquals(null, r.MasterLabel,
                'Rule label should not be null');
            System.assertNotEquals(null, r.svfhc__Severity__c,
                'Rule severity should not be null');
            System.assertNotEquals(null, r.svfhc__Rule_Type__c,
                'Rule type should not be null');
        }
        System.assert(rules.size() >= 5,
            'Should have at least 5 rules from Phase 1');
    }

     @isTest
    static void testGetScanHistory_ReturnsNewestFirst() {
        Flow_Scan__c scan1 = new Flow_Scan__c(
            Scan_Date__c            = DateTime.now().addDays(-2),
            Status__c               = 'Complete',
            Total_Flows_Scanned__c  = 10,
            Total_Violations__c     = 3,
            Errors__c               = 1,
            Warnings__c             = 2
        );
        Flow_Scan__c scan2 = new Flow_Scan__c(
            Scan_Date__c            = DateTime.now().addDays(-1),
            Status__c               = 'Complete',
            Total_Flows_Scanned__c  = 10,
            Total_Violations__c     = 5,
            Errors__c               = 3,
            Warnings__c             = 2
        );
        Flow_Scan__c scan3 = new Flow_Scan__c(
            Scan_Date__c            = DateTime.now(),
            Status__c               = 'Complete',
            Total_Flows_Scanned__c  = 12,
            Total_Violations__c     = 1,
            Errors__c               = 0,
            Warnings__c             = 1
        );
        insert new List<Flow_Scan__c>{ scan1, scan2, scan3 };

        Test.startTest();
        List<Flow_Scan__c> history =
            FlowHealthCheckerController.getScanHistory(null);
        Test.stopTest();

        System.assertEquals(3, history.size(),
            'Should return all 3 completed scans');
        System.assertEquals(scan3.Id, history[0].Id,
            'Newest scan should be first');
        System.assertEquals(scan1.Id, history[2].Id,
            'Oldest scan should be last');
    }

    @isTest
    static void testGetScanHistory_RespectsMaxRecords() {
        List<Flow_Scan__c> scans = new List<Flow_Scan__c>();
        for (Integer i = 0; i < 3; i++) {
            scans.add(new Flow_Scan__c(
                Scan_Date__c            = DateTime.now().addDays(-i),
                Status__c               = 'Complete',
                Total_Flows_Scanned__c  = 5,
                Total_Violations__c     = i,
                Errors__c               = i,
                Warnings__c             = 0
            ));
        }
        insert scans;

        Test.startTest();
        List<Flow_Scan__c> history =
            FlowHealthCheckerController.getScanHistory(2);
        Test.stopTest();

        System.assertEquals(2, history.size(),
            'Should respect the maxRecords limit of 2');
    }

    @isTest
    static void testGetScanHistory_ExcludesIncompleteScans() {
        Flow_Scan__c completeScan = new Flow_Scan__c(
            Scan_Date__c            = DateTime.now(),
            Status__c               = 'Complete',
            Total_Flows_Scanned__c  = 5,
            Total_Violations__c     = 1,
            Errors__c               = 1,
            Warnings__c             = 0
        );
        Flow_Scan__c runningScan = new Flow_Scan__c(
            Scan_Date__c = DateTime.now(),
            Status__c    = 'Running'
        );
        insert new List<Flow_Scan__c>{ completeScan, runningScan };

        Test.startTest();
        List<Flow_Scan__c> history =
            FlowHealthCheckerController.getScanHistory(null);
        Test.stopTest();

        System.assertEquals(1, history.size(),
            'Should only return Complete scans, not Running ones');
        System.assertEquals(completeScan.Id, history[0].Id,
            'The returned scan should be the completed one');
    }
}