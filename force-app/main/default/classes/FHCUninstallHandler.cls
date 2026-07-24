public class FHCUninstallHandler implements UninstallHandler {

    public void onUninstall(UninstallContext context) {
        try {
            deleteScanData();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'FHC Uninstall handler failed: ' + e.getMessage()
            );
        }
    }

    private void deleteScanData() {
        // Delete all scan results first (child records)
        List<Flow_Scan_Result__c> results = [
            SELECT Id FROM Flow_Scan_Result__c LIMIT 10000
        ];
        if (!results.isEmpty()) {
            delete results;
        }

        // Delete all scan header records
        List<Flow_Scan__c> scans = [
            SELECT Id FROM Flow_Scan__c LIMIT 10000
        ];
        if (!scans.isEmpty()) {
            delete scans;
        }
    }
}