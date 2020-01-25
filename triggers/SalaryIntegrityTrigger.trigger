trigger SalaryIntegrityTrigger on Salary__c (before insert, before update, after undelete) {
	// This trigger keeps the 1:1 integrity of Position:Salary 
	// 	1. Adds errors to duplicates found within the Trigger batch itself
	// 	2. Adds errors to duplicates found by checking the Database for dupes
	
	Map<ID,Salary__c> posIdToSalaryMap = new Map<ID,Salary__c>(); // Map of PositionId-->Salary record
	List<ID> duplicates = new List<ID>(); // List of duplicate salary records found, based on Position Id of the Salary record
	
	// From the list of Trigger records (in memory), build the Map of unique salary records & 
	// 	build the List of duplicate salary records
	for(Salary__c salary:Trigger.new){
		if (salary.position__c != null){
			if (!posIdToSalaryMap.containsKey(salary.position__c)){
				posIdToSalaryMap.put(salary.position__c,salary);
			} else {
				salary.position__c.addError('Batch contains more than one salary record for the same position');
				posIdToSalaryMap.get(salary.position__c).position__c.addError('Only one salary record is allowed per position');				
				// keep track of duplicates found so we can take them out of the Map once
				//	we're done looping through the full set of Trigger records
				duplicates.add(salary.position__c);  // remember, this list could contain the same position id more than once
			}
		} else {
			salary.position__c.addError('Position is a required	field');
		}
	}
	
	// remove duplicates from the Map
	for(ID posId:duplicates){
		// remove from the Map because we've already added an error message to the corresponding salary record
		if (posIdToSalaryMap.containsKey(posId)) posIdToSalaryMap.remove(posId);	
	}
	
	// Query the database for any existing duplicates based on the Map keySet
	for(List<Salary__c> salaryList:[select id,position__c,name from salary__c s where position__c IN :posIdToSalaryMap.keySet()]){
		for(Salary__c salary:salaryList){
			// if there is record in the Map that matches the current database record of the loop
			//	AND the record in the Map is not exactly the same record as the one from the database (for update triggers)
			if((posIdToSalaryMap.containsKey(salary.position__c)) && 
				(salary.id != posIdToSalaryMap.get(salary.position__c).id))
			{
				posIdToSalaryMap.get(salary.position__c).position__c.addError('A salary record already exists for this position (duplicate: <a href=\'/' + salary.id + '\'>' + salary.name + '</a>)');
			}	
		}
	}
}