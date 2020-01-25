trigger PositionJobPostsTrigger on Position__c (after update, after delete) {
	
	if (Trigger.isUpdate){
		// Separate the positions into 2 lists: 1 for Tech Positions, 1 for non-tech Positions
		List<Position__c> techPositions = new List<Position__c>();
		List<Position__c> nonTechPositions = new List<Position__c>();
		Set<ID> nonApprovedPositionIDSet = new Set<ID>();
		
		for (Position__c position:Trigger.new){
			if (position.Status__c == 'Open' && position.Sub_Status__c == 'Approved'){
				if (position.Department__c != null) {
					if ((position.Department__c != 'IT')&&(position.Department__c !='Engineering')){
						nonTechPositions.add(position);
					} else{
						techPositions.add(position); 
					}
				}
			} else {
				// make sure there are no Job Postings associated with the position
				nonApprovedPositionIDSet.add(position.Id);
			}	
		}
		if (nonTechPositions.size() > 0) PositionJobPosts.newPositionPosting(nonTechPositions,false);
		if (techPositions.size() > 0) PositionJobPosts.newPositionPosting(techPositions,true);
		if (nonApprovedPositionIDSet.size() > 0) PositionJobPosts.removePositionPostings(nonApprovedPositionIDSet,Trigger.newMap);
	} else if (Trigger.isDelete){
		PositionJobPosts.removePositionPostings(Trigger.oldMap.keySet(),Trigger.oldMap);
	}
}