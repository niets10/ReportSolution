({
    getResponseFromApex : function(component, action, toSet) {

            action.setCallback(this, function(response) {
                var state = response.getState();
                if(component.isValid() && state === "SUCCESS") {
                    
                    var res = response.getReturnValue();
                    component.set(toSet, res);
                } else {
                    console.log("Failed with state: " + state);
                }
            });
            
            $A.enqueueAction(action);
     

    },
})