/**
 @Name: GetObjectFields.cls
 @TestedBy: ReportsController_Test.cls
 @Other classes used:
 @Description: Description:
    Get all fields name of an specific object

 @History
  VERSION     AUTHOR           DATE            DETAIL
  1.0         Álvaro Nieto     12/9/2020       First version
*/
public class GetObjectFields {
    
    public static List<String> getFieldsForObject(String objectApiName) {
        
        Map <String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
        Map <String, Schema.SObjectField> fieldsMap = schemaMap.get(objectApiName).getDescribe().fields.getMap();

        List<String> fieldApiNames = new List<String>();
        for(Schema.SObjectField f : fieldsMap.values()){
            
            Schema.DescribeFieldResult field = f.getDescribe();
            
            String fieldName = field.getName();
            String fieldLabel = field.getLabel();
            
            fieldApiNames.add(fieldName);
        }

        return fieldApiNames;

    }
}