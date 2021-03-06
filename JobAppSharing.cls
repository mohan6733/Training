public class JobAppSharing {
	
	public static void createSharing(List<Job_Application__c> jobApplications, String sharingReason, String accessLevel){
		// Create a Map of the jobApp's Position__c ids to a Set of jobApp IDs that share the Position__c id
		Map<ID,List<Job_Application__c>> posIdToAppMap = new Map<ID,List<Job_Application__c>>();
		for(Job_Application__c jobApp : jobApplications){
			if (!posIdToAppMap.containsKey(jobApp.position__c)){
				// Add the initial entry for this position id
				List<Job_Application__c> appList = new List<Job_Application__c> {jobApp};
				posIdToAppMap.put(jobApp.position__c,appList);
			} else {
				// Add additional jobApp ids to the Set related to the position id key
				List<Job_Application__c> appList = posIdToAppMap.get(jobApp.position__c);
				posIdToAppMap.put(jobApp.position__c,appList);
			}
		}
		
		List<Job_Application__Share> jobShares = new List<Job_Application__Share>(); // the total list of job sharing records
		List<Candidate__Share> candShares = new List<Candidate__Share>(); 	     // the total list of candidate sharing records
			
		if (sharingReason == 'Position_Interviewer__c'){
			// get the interviewers for each job app position 	
			for(List<Interviewer__c> interviewers : [select id,employee__c,position__c from interviewer__c where position__c IN :posIdToAppMap.keySet()]){
				// loop thru the list of interviewers and create sharing records
				for(Interviewer__c interviewer : interviewers){
					// loop thru the jobApps corresponding to the interviewer's position
					for(Job_Application__c job : posIdToAppMap.get(interviewer.position__c)){
						Job_Application__Share jobShare = new Job_Application__Share();
						jobShare.parentId = job.Id;
						jobShare.UserOrGroupId = interviewer.employee__c;
						jobShare.RowCause = Schema.Job_Application__Share.RowCause.Position_Interviewer__c;
						jobShare.AccessLevel = accessLevel;
						jobShares.add(jobShare);
						
						if (job.candidate__c != null){
							Candidate__Share candShare = new Candidate__Share();
							candShare.parentId = job.candidate__c;
							candShare.UserOrGroupId = interviewer.employee__c;
							candShare.RowCause = Schema.Candidate__Share.RowCause.Position_Interviewer__c;
							candShare.AccessLevel = 'Read'; // for interviewers it's always ReadOnly
							candShares.add(candShare);
						}
					}
				}
			}
		} else if (sharingReason == 'Hiring_Manager__c'){
			// Create Set of JobAppID --> JobApps
			Set<ID> jobAppIdSet = new Map<ID,Job_Application__c>(jobApplications).keySet();
			
			// Get the job applications, pull in the hiring mgr fields from the position 	
			// For(List<Job_Application__c> jobs : [select j.id,j.position__c,j.candidate__c,j.position__r.hiring_manager__c from Job_Application__c j where j.ID IN :jobAppIdSet and j.position__r.hiring_manager__c != null]){
				// Loop thru the list of jobApps and create sharing records
				for(Job_Application__c job : jobApplications){
					Job_Application__Share jobShare = new Job_Application__Share();
					jobShare.parentId = job.Id;
					jobShare.UserOrGroupId = job.position__r.hiring_manager__c;
					jobShare.RowCause = Schema.Job_Application__Share.RowCause.Hiring_Manager__c;
					jobShare.AccessLevel = accessLevel;
					jobShares.add(jobShare);
						
					if (job.candidate__c != null){
						Candidate__Share candShare = new Candidate__Share();
						candShare.parentId = job.candidate__c;
						candShare.UserOrGroupId = job.position__r.hiring_manager__c;
						candShare.RowCause = Schema.Candidate__Share.RowCause.Hiring_Manager__c;
						candShare.AccessLevel = accessLevel;
						candShares.add(candShare);
					}					
				}
			// }
		}
		
		// Insert the jobShares
		try{
			Database.SaveResult[] results = Database.insert(jobShares,false);	
			if (candShares.size() > 0) {
				Database.SaveResult[] candResults = Database.insert(candShares,false);
				results.addAll(candResults);
			}
			if (results != null){
				List<Error_Log__c> errors = new List<Error_Log__c>();
				for (Database.SaveResult result : results){
					if (!result.isSuccess()){
						Error_Log__c log = new Error_Log__c();
						log.trace__c = '';
						Database.Error[] errs = result.getErrors();	
						for(Database.Error err : errs){
							log.trace__c += err.getStatusCode() + '\n' + err.getMessage();
						}
						errors.add(log);
					}	
				}	
				if (errors.size() > 0){
					insert errors;	
				}
			}
		} catch (Exception e){
			Error_Log__c log = new Error_Log__c();
            log.trace__c = e.getTypeName() + '\n' + e.getCause() + '\n' + e.getMessage();
            insert log;
		}
	}
	
	public static void createSharing(List<Position__c> positions, String sharingReason, String accessLevel){
		// Build a Position ID Set
		Set<ID> posIdSet = new Map<ID,Position__c>(positions).keySet();
		for(List<Job_Application__c> jobApps : [select j.id,j.position__c,j.candidate__c,j.position__r.hiring_manager__c from Job_Application__c j where j.position__c IN :posIdSet and j.position__r.hiring_manager__c != null]){
			JobAppSharing.createSharing(jobApps,sharingReason,accessLevel);
		}
	}
	
	public static void closeHiringMgrSharing(List<Job_Application__c> closedJobApps){
		if (closedJobApps.size() > 0){
			Set<ID> closedJobAppSet = new Map<ID,Job_Application__c>(closedJobApps).keySet();
			// Go through the list of related sharing records in batch and update any Hiring Manager
			//	sharing records to be Read Only
			for(List<Job_Application__Share> batchOfShares:[select UserOrGroupId, RowCause, ParentId, Id, AccessLevel From Job_Application__Share where ParentId IN :closedJobAppSet and RowCause='Hiring_Manager__c']){
				for(Job_Application__Share jobShare:batchOfShares){
					jobShare.AccessLevel = 'Read';	
				}
				try {
					update batchOfShares;	
				} catch (System.DmlException e){
					System.debug('error bulk updating position shares');
					for (Integer k = 0; k < e.getNumDml(); k++) {
						// Process exception here
						System.debug(e.getDmlMessage(k));
					}
				}
			}
		}
	}
	
	public static void closeHiringMgrSharing(List<Position__c> closedPositions){
		if (closedPositions.size() > 0){
			Set<ID> posIdSet = new Map<ID,Position__c>(closedPositions).keySet();
			List<Job_Application__c> jobApps = new List<Job_Application__c>();
			for(List<Job_Application__c> jobs : [select j.id,j.position__c,j.candidate__c,j.position__r.hiring_manager__c from job_application__c j where j.position__c IN :posIdSet]){
				jobApps.addAll(jobs);
			}
			JobAppSharing.closeHiringMgrSharing(jobApps);
		}
	}
	
	public static void deleteHiringMgrSharing(Map<ID,ID> posIdToNewMgrIdMap){
		if (posIdToNewMgrIdMap.size() > 0){
			// create a job App Map that Maps the JobAppId --> New Hiring Manager Id
			Map<ID,ID> jobIdToNewMgrIdMap = new Map<ID,ID>();
			// create a candidate Map that Maps the JobAppId --> New Hiring Manager Id
			Map<ID,ID> candIdToNewMgrIdMap = new Map<ID,ID>();
			for(List<Job_Application__c> jobApps : [select id,position__c,candidate__c from job_application__c where position__c IN :posIdToNewMgrIdMap.keySet()]){
				for(Job_Application__c jobApp : jobApps){
					jobIdToNewMgrIdMap.put(jobApp.id,posIdToNewMgrIdMap.get(jobApp.position__c));
					if (jobApp.candidate__c != null) candIdToNewMgrIdMap.put(jobApp.candidate__c,posIdToNewMgrIdMap.get(jobApp.position__c));
				}
			}
			
			// Go through the list of related sharing records in batch and remove old Hiring Manager shares
			for(List<Job_Application__Share> batchOfShares:[select UserOrGroupId, RowCause, ParentId, Id, AccessLevel From Job_Application__Share where ParentId IN :jobIdToNewMgrIdMap.keySet() and RowCause='Hiring_Manager__c']){
				List<Job_Application__Share> deleteShares = new List<Job_Application__Share>();
				for(Job_Application__Share jobShare:batchOfShares){
					if (jobIdToNewMgrIdMap.get(jobShare.ParentId) != jobShare.UserOrGroupId){
						deleteShares.add(jobShare);
					}
				}
				try {
					delete deleteShares;	
				} catch (System.DmlException e){
					System.debug('error bulk deleting position shares');
					for (Integer k = 0; k < e.getNumDml(); k++) {
						// Process exception here
						System.debug(e.getDmlMessage(k));
					}
				} 
			}
			// Do the same thing for candidates as we just did for job apps
			for(List<Candidate__Share> batchOfShares:[select UserOrGroupId, RowCause, ParentId, Id, AccessLevel From Candidate__Share where ParentId IN :candIdToNewMgrIdMap.keySet() and RowCause='Hiring_Manager__c']){
				List<Candidate__Share> deleteShares = new List<Candidate__Share>();
				for(Candidate__Share candShare:batchOfShares){
					if (candIdToNewMgrIdMap.get(candShare.ParentId) != candShare.UserOrGroupId){
						deleteShares.add(candShare);
					}
				}
				try {
					delete deleteShares;	
				} catch (System.DmlException e){
					System.debug('error bulk deleting position shares');
					for (Integer k = 0; k < e.getNumDml(); k++) {
						// Process exception here
						System.debug(e.getDmlMessage(k));
					}
				}
			}
		}
	}
}