({
    //Init handler
    doInit : function(component, event, helper) {

        var action = component.get("c.getReports");        
        helper.getResponseFromApex(component, action, "v.reports");

    },
    
    //Handle end flow
    handleStatusChange : function (component, event, helper) {
        if(event.getParam("status") === "FINISHED") {
             var toastEvent = $A.get("e.force:showToast");
             toastEvent.setParams({
                 "type": "success",
                 "title": "Success!",
                 "message": "The flow has finished correctly."
             });
             toastEvent.fire();

             //Refresh the view from the beginning
             $A.get('e.force:refreshView').fire();
            
         }
     },

    //On Report selection
    onSelection : function (component, event, helper) {

        //Detroy flow component as it will later be created
        var flow = component.find("reportFlow");
        if(flow !== undefined){
            flow.destroy();
        }

        var reportDeveloperName = event.getParam('name');         

        
        component.set("v.reportDeveloperName", reportDeveloperName);
        
        var action = component.get("c.getRecords");
        action.setParams({ reportName : reportDeveloperName });

        action.setCallback(this, function(response) {
            var state = response.getState();
            if(component.isValid() && state === "SUCCESS") {
                var response = response.getReturnValue();
                if(response.flowNames.length > 0 && response.records.length > 0){
                    component.set("v.objects", response.records);
                    component.set("v.flows", response.flowNames);
                    component.set("v.report", response.report);                    
                }else{
                    component.set("v.report", response.report);
                    component.set("v.flows", []);
                }

                component.set("v.showFlowMenu", true);
            } else {
                console.log("Failed with state: " + state);
            }
        });

        $A.enqueueAction(action);
    },

    //On Flow selection
    onSelectionFlow :function (component, event, helper) {
        
        var flowDeveloperName = event.getParam('name');  
        component.set("v.flowDeveloperName", flowDeveloperName);      

        var records = component.get("v.objects");

        //TO DO: Retrieve input variables dynamically from APEX
        var inputVariables = [
            {
                name: 'Records',
                type: 'SObject',
                value: records
            }
        ];

        /** When the lightning:flow was in the markup, the flow was not being updated everytime we clicked in a different
         * flow, so the same was flow called all the time.
         * To solve we will destroy the lightning:flow (if there was any) and after we'll generate it dynamically.
          */
        let flow = component.find("reportFlow");
        if(flow !== undefined){
            flow.destroy();
        }

        $A.createComponent(
            "lightning:flow",
            {
                "aura:id": "reportFlow",
                "onstatuschange": component.getReference("c.handleStatusChange")
            },
            function(newButton, status, errorMessage){
                //Add the new button to the body array
                if (status === "SUCCESS") {
                    var body = component.get("v.body");
                    body.push(newButton);
                    component.set("v.body", body);

                    flow = component.find("reportFlow");
                    flow.startFlow(flowDeveloperName, inputVariables);
                }
                else if (status === "INCOMPLETE") {
                    console.log("No response from server or client is offline.")
                    // Show offline error
                }
                else if (status === "ERROR") {
                    console.log("Error: " + errorMessage);
                    // Show error message
                }
            }
        );
    },

    //Reports search function
    handleNameFilterChange : function(component, event, helper){
        var nameFilterString = component.find("nameFilter").get("v.value");

        const action = component.get("c.getFilteredReports");
        action.setParams({
            nameFilterString: nameFilterString
        });

        helper.getResponseFromApex(component, action, "v.reports");
    },

    //Link to navigate to selected report
    navigateToRecord : function(component, event, helper) {

        var report = component.get("v.report");

        var pageReference = {
            type: "standard__recordPage",
            attributes: {
                objectApiName: 'Report',
                actionName: 'view',
                recordId : report.Id

            }
        }

        //Open the report in a new tab
        var navService = component.find("nav");
        navService.generateUrl(pageReference).then($A.getCallback(function(url) { 
            console.log('Using Navigate'+url); 
            //---add this line which allows you to open url in new tab instead of navService 
           /*  window.open('https:'+url,
                        '_blank' // <- This is what makes it open in a new window.
                       ); */
            
            component.set("v.url", url ? url : defaultUrl);           
            }),$A.getCallback(function(error) {
            console.log(error); 
        }));
    }
})