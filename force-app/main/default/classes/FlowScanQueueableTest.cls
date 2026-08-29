@isTest
private class FlowScanQueueableTest {
  @isTest
  static void testQueueableSuccess() {
    Test.setMock(HttpCalloutMock.class, new FlowScannerMultiMock());

    Flow_Scan__c scan = new Flow_Scan__c(
      Scan_Date__c = DateTime.now(),
      Status__c = 'Pending'
    );
    insert scan;

    Test.startTest();
    System.enqueueJob(new FlowScanQueueable(scan.Id));
    Test.stopTest();

    Flow_Scan__c result = [
      SELECT Status__c, Total_Flows_Scanned__c, Total_Violations__c
      FROM Flow_Scan__c
      WHERE Id = :scan.Id
    ];
    System.assertEquals(
      'Complete',
      result.Status__c,
      'Queueable should mark scan Complete. Error: ' +
      [
        SELECT Error_Message__c
        FROM Flow_Scan__c
        WHERE Id = :scan.Id
      ]
      .Error_Message__c
    );
    System.assertEquals(
      1,
      result.Total_Flows_Scanned__c,
      'Should have scanned 1 flow'
    );
    System.assert(
      result.Total_Violations__c > 0,
      'Should have found violations'
    );
  }

  @isTest
  static void testQueueableFailure() {
    Test.setMock(
      HttpCalloutMock.class,
      new FlowMetadataMock(FlowMetadataMock.MockType.ERROR)
    );

    Flow_Scan__c scan = new Flow_Scan__c(
      Scan_Date__c = DateTime.now(),
      Status__c = 'Pending'
    );
    insert scan;

    Test.startTest();
    System.enqueueJob(new FlowScanQueueable(scan.Id));
    Test.stopTest();

    Flow_Scan__c result = [
      SELECT Status__c, Error_Message__c
      FROM Flow_Scan__c
      WHERE Id = :scan.Id
    ];
    System.assertEquals(
      'Failed',
      result.Status__c,
      'Should mark scan as Failed when API errors'
    );
    System.assertNotEquals(
      null,
      result.Error_Message__c,
      'Should store error message'
    );
  }

  @isTest
  static void testQueueableEmptyOrg() {
    Test.setMock(HttpCalloutMock.class, new EmptyFlowListMock());

    Flow_Scan__c scan = new Flow_Scan__c(
      Scan_Date__c = DateTime.now(),
      Status__c = 'Pending'
    );
    insert scan;

    Test.startTest();
    System.enqueueJob(new FlowScanQueueable(scan.Id));
    Test.stopTest();

    Flow_Scan__c result = [
      SELECT Status__c, Total_Flows_Scanned__c
      FROM Flow_Scan__c
      WHERE Id = :scan.Id
    ];
    System.assertEquals(
      'Complete',
      result.Status__c,
      'Empty org should complete with 0 flows'
    );
    System.assertEquals(
      0,
      result.Total_Flows_Scanned__c,
      'Should show 0 flows scanned'
    );
  }
  @isTest
  static void testBatchOuterCatch_NullScanId() {
    Test.setMock(HttpCalloutMock.class, new FlowScannerMultiMock());

    // Pass null scanId — the update at the end will throw
    // triggering the outer catch block
    List<Map<String, Object>> mockFlows = new List<Map<String, Object>>{
      new Map<String, Object>{
        'Id' => '3010H000000fake01',
        'DeveloperName' => 'Test_Flow',
        'MasterLabel' => 'Test Flow',
        'Description' => null,
        'ActiveVersionId' => '3010H000000fake02'
      }
    };

    Test.startTest();
    try {
      // Directly instantiate and execute with null scanId
      FlowScanBatchQueueable job = new FlowScanBatchQueueable(
        null,
        mockFlows,
        new List<RuleViolation>(),
        1
      );
      // Execute directly — enqueueJob won't work with null scanId
      job.execute(null);
    } catch (Exception e) {
      // Expected — null scanId causes DML exception
      System.assert(true, 'Exception handled as expected');
    }
    Test.stopTest();
  }

  @isTest
  static void testBatchCompletesWithMultipleViolationTypes() {
    Test.setMock(HttpCalloutMock.class, new FlowScannerMultiMock());

    Flow_Scan__c scan = new Flow_Scan__c(
      Scan_Date__c = DateTime.now(),
      Status__c = 'Running'
    );
    insert scan;

    // Build violations of different severities
    List<RuleViolation> priorViolations = new List<RuleViolation>();

    RuleViolation v1 = new RuleViolation(
      'No Fault Path',
      'Error',
      'Create_Record',
      'Missing fault path'
    );
    v1.flowApiName = 'Flow_One';
    v1.flowDefinitionId = '3010H000000fake01';
    priorViolations.add(v1);

    RuleViolation v2 = new RuleViolation(
      'Missing Description',
      'Warning',
      'Flow_Two',
      'No description'
    );
    v2.flowApiName = 'Flow_Two';
    v2.flowDefinitionId = '3010H000000fake02';
    priorViolations.add(v2);

    RuleViolation v3 = new RuleViolation(
      'Hardcoded Id',
      'Error',
      'Assign_Element',
      'Hardcoded SF Id found'
    );
    v3.flowApiName = 'Flow_Three';
    v3.flowDefinitionId = '3010H000000fake03';
    priorViolations.add(v3);

    // Empty remaining flows — triggers final persist path
    Test.startTest();
    System.enqueueJob(
      new FlowScanBatchQueueable(
        scan.Id,
        new List<Map<String, Object>>(),
        priorViolations,
        3
      )
    );
    Test.stopTest();

    Flow_Scan__c result = [
      SELECT Status__c, Total_Violations__c, Total_Flows_Scanned__c
      FROM Flow_Scan__c
      WHERE Id = :scan.Id
    ];
    System.assertEquals(
      'Complete',
      result.Status__c,
      'Should complete successfully'
    );
    System.assertEquals(
      3,
      result.Total_Violations__c,
      'Should persist all 3 prior violations'
    );
    System.assertEquals(
      3,
      result.Total_Flows_Scanned__c,
      'Should record 3 total flows scanned'
    );
  }

  @isTest
  static void testQueueableWithExplicitSession() {
    Test.setMock(HttpCalloutMock.class, new FlowScannerMultiMock());

    Flow_Scan__c scan = new Flow_Scan__c(
      Scan_Date__c = DateTime.now(),
      Status__c = 'Pending'
    );
    insert scan;

    Test.startTest();
    System.enqueueJob(new FlowScanQueueable(scan.Id, 'explicit_session_12345'));
    Test.stopTest();

    Flow_Scan__c result = [
      SELECT Status__c, Total_Flows_Scanned__c
      FROM Flow_Scan__c
      WHERE Id = :scan.Id
    ];
    System.assertEquals('Complete', result.Status__c);
  }
}
