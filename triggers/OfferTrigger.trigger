trigger OfferTrigger on Offer__c (after insert, after update) {
	// Create a List to hold the JobApps to be updated
	List<Job_Application__c> jobApps = new List<Job_Application__c>();
	// There is a validation rule on the Offer__c object that requires Job_Application__c
	//	to be specified.  Therefore we can assume all offers have a valid JobApplication.
//	for(List<Offer__c> offers:[select id,job_application__c,job_application__r.stage__c,job_application__r.status__c,job_application__r.name from offer__c where id IN :Trigger.newMap.keySet()]){
	for(List<Offer__c> offers:[select job_application__r.name from offer__c where id IN :Trigger.newMap.keySet()]){

		for(Offer__c offer:offers){
			offer.job_application__r.stage__c = 'Offer Extended';
			offer.job_application__r.status__c = 'Hold';
			jobApps.add(offer.job_application__r);
		}
	}
	// perform the update of job application records
	if (jobApps.size() > 0){
		try{
			Database.SaveResult[] saveResults = Database.update(jobApps,false);
			
			// Now go through the results and send errors to the debug log
			Integer x = 0;
			for(Database.SaveResult result:saveResults){				
				if(!result.isSuccess()){
					// Get the first save result error
					Database.Error err = result.getErrors()[0];	
					System.debug('Unable to update Job Application, ' + jobApps[x].name + '.  Error:'+ err.getMessage());				
				}
				x++;			
			}
		} catch (Exception e){
			System.debug('error updating job applications:' + e);	
		}
	}
}