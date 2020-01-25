trigger SalarySharingTrigger on Salary__c (after insert) {

	List<Salary__c> mgrRecords = new List<Salary__c>();
	List<Salary__c> vpRecords = new List<Salary__c>();
	List<Salary__c> triggerRecords = [select id,position__c,position__r.hiring_manager__c,position__r.department__c from salary__c where id IN :Trigger.newMap.keySet()];
	// Loop through the salary records, as long as a hiring mgr and department exist on the 
	//	respective position records then create the hiring mgr and vp shares
	for(Salary__c salary:triggerRecords){
		if (salary.position__c != null){
			System.debug('position__r.hiring_mgr=' + salary.position__r.hiring_manager__c);
			if(salary.position__r.hiring_manager__c != null) mgrRecords.add(salary);
			if(salary.position__r.department__c != null) vpRecords.add(salary);	
		} else {
			salary.position__c.addError('Position is a required field');	
		}
	}	
	// Now call the share creation methods
	if (mgrRecords != null && mgrRecords.size() > 0) SalarySharing.addSharing(mgrRecords,'Hiring_Manager__c','Edit');
	if (vpRecords != null && vpRecords.size() > 0) SalarySharing.addSharing(vpRecords,'Department_VP__c','Edit');
}