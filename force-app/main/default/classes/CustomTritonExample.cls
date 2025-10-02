public with sharing class CustomTritonExample {

    public static final String ID_IN_ERP = 'ID_ERP__c';
    public static final String ACCOUNT_NAME = 'Account_Name__c';
    public static final String ITE_NUMBER = 'ITENumber__c';

    public static void addError(TritonTypes.Type type, TritonTypes.Area area, String summary, String details, String iteNumber) {
        Triton.instance.addLog(getErrorBuilder(type, area, summary, details, iteNumber));
    }

    public static void error(TritonTypes.Type type, TritonTypes.Area area, String summary, String details, String iteNumber) {
        Triton.instance.log(getErrorBuilder(type, area, summary, details, iteNumber));
    }

    public void addIntegrationError(
        TritonTypes.Type type,
        TritonTypes.Area area,
        String summary,
        String details,
        RestRequest request,
        RestResponse response, 
        String accountName, 
        String accountIdERP, 
        String iteNumber
    ) {
        Triton.instance.addLog(getIntegrationErrorBuilder(type, area, summary, details, request, response, accountName, accountIdERP, iteNumber));
    }

    public void integrationError(
        TritonTypes.Type type,
        TritonTypes.Area area,
        String summary,
        String details,
        RestRequest request,
        RestResponse response, 
        String accountName, 
        String accountIdERP, 
        String iteNumber
    ) {
        Triton.instance.log(getIntegrationErrorBuilder(type, area, summary, details, request, response, accountName, accountIdERP, iteNumber));
    }

    private static TritonBuilder getErrorBuilder(TritonTypes.Type type, TritonTypes.Area area, String summary, String details, String iteNumber) {
        return Triton.instance.getErrorBuilder(type, area, summary, details)
            .attribute(ITE_NUMBER, iteNumber);
    }

    private static TritonBuilder getIntegrationErrorBuilder(
        TritonTypes.Type type,
        TritonTypes.Area area,
        String summary,
        String details,
        RestRequest request,
        RestResponse response, 
        String accountName, 
        String accountIdERP, 
        String iteNumber
    ) {
        return Triton.instance.getIntegrationErrorBuilder(type, area, summary, details, request, response)
            .attribute(ACCOUNT_NAME, accountName)
            .attribute(ID_IN_ERP, accountIdERP)
            .attribute(ITE_NUMBER, iteNumber);
    }
}