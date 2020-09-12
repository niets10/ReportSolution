/**
 @Name: ReportsController.cls
 @TestedBy: ReportsController_Test.cls
 @Other classes used: GetObjectFields.cls
 @Description: Description:
    APEX custom controller to be called from ReportsFlowCmp.

 @History
  VERSION     AUTHOR           DATE            DETAIL
  1.0         Álvaro Nieto     10/9/2020       First version
  1.1         Álvaro Nieto     12/09/2020      Add method to get all the fields of the object dynamically
*/

public class ReportsController {

    /**
     * @Description: Return an object with properties
      */
    public class Payload {

        @AuraEnabled public List<String> flowNames {get; set;}
        @AuraEnabled public List<sObject> records {get; set;}
        @AuraEnabled public Report report {get;set;}

    }

    /**
     * @Description: Avoid SOQL injection
      */
    private static String sanitizeQueryString(String aQuery) {
        if (aQuery == null) return '%';
        
        String trimmedQuery = aQuery.trim();
        if (trimmedQuery.length() == 0) return '%';
        return '%' + trimmedQuery.replaceAll('\\W+', '%') + '%';
    }
    
    /**
     * @Description: Method to enable the report search
      */
    @AuraEnabled
    public static List<Report> getFilteredReports(String nameFilterString){
        
        String composedFilter = sanitizeQueryString(nameFilterString);
        
        List<Report> filteredReports = [SELECT Id, Name, DeveloperName FROM Report WHERE Name LIKE :composedFilter ORDER BY Name];
        
        return filteredReports;

    }

    /**
     * @Description: Get all the reports on init handler of the associated LC
      */
    @AuraEnabled
    public static List<Report> getReports(){

        return [SELECT Id, DeveloperName, Name FROM Report ORDER BY Name];
        
    }
    
    /**
     * @Description: Fetch collection of records from the selected Report
      */
    @AuraEnabled
    public static Payload getRecords(String reportName){

        List<Report> reportList = [SELECT Id, Name, DeveloperName FROM Report WHERE DeveloperName =: reportName];

        //Using custom metadata allows more flexibility so there's no need to change the code for every implementation
        List<ReportsSolution__mdt> customMetadata = [SELECT ColumnTarget__c, ObjectAPIName__c, 
                                                    ReportDeveloperName__c, FlowDeveloperName__c 
                                                    FROM ReportsSolution__mdt
                                                    WHERE ReportDeveloperName__c =: reportName];

        //If no metadata configured, we stop the process
        Payload pld = new Payload();        

        if(customMetadata.isEmpty()) {
            pld.report = reportList[0];
            pld.flowNames = new List<String>();
            pld.records = new List<sObject>();

            return pld;
        }         

        List<String> flowNames = new List<String>();        
        for(ReportsSolution__mdt cm : customMetadata){
            flowNames.add(cm.FlowDeveloperName__c);
        }                                            
                                                    

        //Run report
        String reportId = (String) reportList.get(0).get('Id');        
        Reports.reportResults results = Reports.ReportManager.runReport(reportId, true);

        //Get results
        Map<String,Reports.ReportFact> factMap = results.getFactMap();        

        /* A report could have different groupping by rows, if we have two, 
        * the first groupping won't have any detailed row so we will filter out keys without detailed rows
        */
        List<String> relevantKeys = new List<String>();
        for(String key : factMap.keySet()){

            Reports.ReportFactWithDetails fd = (Reports.ReportFactWithDetails) results.getFactMap().get(key);
            List<Reports.ReportDetailRow> detailsRows = fd.getRows();
            if(!detailsRows.isEmpty()) relevantKeys.add(key);

        }

        //Iterate through the keys with detailed rows
        Set<Id> relevantIds = new Set<Id>();
        Set<String> names = new Set<String>();
        ReportsSolution__mdt cmd = customMetadata[0];
        for(String key : relevantKeys){

            Integer loopCount = 0;
            Reports.ReportFactWithDetails fd = (Reports.ReportFactWithDetails) results.getFactMap().get(key);
            List<Reports.ReportDetailRow> rows = fd.getRows();

            //Get the detail rows for each grouping            
            for(Reports.ReportDetailRow r : rows){
                //Iterate through each of the rows, getting the value
                Integer columnTarget = (Integer) cmd.ColumnTarget__c;
                relevantIds.add( (Id) fd.getRows()[loopCount].getDataCells()[columnTarget].getValue() );
                loopCount++;
            }
           
        }

        //Get ObjectAPIName from metadata and its fields using Schema.getGlobalDescribe();
        String objectApiName = cmd.ObjectAPIName__c;
        List<String> fieldApiNames = GetObjectFields.getFieldsForObject(objectApiName);
        String stringFields = String.join(fieldApiNames, ',');

        String query = 'SELECT ' + stringFields + ' FROM ' + objectApiName + ' WHERE Id IN: relevantIds';

        List<sObject> listOfSobjects = Database.query(query);

        System.debug('List of objects ' + listOfSobjects);

        pld.flowNames = flowNames;
        pld.records = listOfSobjects;
        pld.report = reportList[0];

        return pld;
    }
}