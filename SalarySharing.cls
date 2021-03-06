public class SalarySharing {
	
	static final Map<String,ID> DEPT_VP_MAP_CONST;
	
	static {DEPT_VP_MAP_CONST = getDepartmentVPMap();}
	
	private static Map<String,ID> getDepartmentVPMap(){
		// build a Map of Department names --> User Ids of the Vice Presidents of the depts
		Map<String,ID> vpMap = new Map<String,ID>();
		// we're assuming there are less than 1,000 departments
		for(Dept_VP__c deptVP:[select id,name,Vice_President__c from Dept_VP__c]){
			if (deptVP.vice_president__c != null){
				if(!vpMap.containsKey(deptVP.name)) vpMap.put(deptVP.name,deptVP.vice_president__c);
			}
		}
		return vpMap;
	}
	
	
	public static void deleteHiringMgrSharing(Map<ID,ID> posIdToNewMgrIdMap){
		if (posIdToNewMgrIdMap.size() > 0){
			// build a Map that links Salary Ids to Position HiringMgr Ids from the Map passed in
			Map<ID,Salary__c> salMap = new Map<ID,Salary__c>([select id,position__c,position__r.department__c,position__r.hiring_manager__c from salary__c where position__c IN :posIdToNewMgrIdMap.keySet()]);
			
			// go through the list of related sharing records in batch and update any Hiring Manager
			//	sharing records to be Read Only
			for(List<Salary__Share> batchOfShares:[select UserOrGroupId, RowCause, ParentId, Id, AccessLevel From Salary__Share where ParentId IN :salMap.keySet() and RowCause='Hiring_Manager__c']){
				List<Salary__Share> deleteShares = new List<Salary__Share>();
				for(Salary__Share salShare:batchOfShares){
					if (posIdToNewMgrIdMap.get(salMap.get(salShare.ParentId).position__c) != salShare.UserOrGroupId){
						deleteShares.add(salShare);
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
	
	public static void deleteVPSharing(Map<ID,String> posIdToDeptMap){
		if (posIdToDeptMap.size() > 0){
			// build a Map that links Salary Ids to position departments from the Map passed in
			Map<ID,Salary__c> salMap = new Map<ID,Salary__c>([select id,position__c,position__r.department__c,position__r.hiring_manager__c from salary__c where position__c IN :posIdToDeptMap.keySet()]);
			
			// go through the list of related sharing records in batch and update any Hiring Manager
			//	sharing records to be Read Only
			for(List<Salary__Share> batchOfShares:[select UserOrGroupId, RowCause, ParentId, Id, AccessLevel From Salary__Share where ParentId IN :salMap.keySet() and RowCause='Department_VP__c']){
				List<Salary__Share> deleteShares = new List<Salary__Share>();
				for(Salary__Share salShare:batchOfShares){
					// check if the position's department even has a VP specified in the Dept_VP table
					if (!DEPT_VP_MAP_CONST.containsKey(posIdToDeptMap.get(salMap.get(salShare.ParentId).position__c))){
						// the position's department does not have a VP specified so delete
						//	the old VP sharing record since it's no longer applicable
						deleteShares.add(salShare);	
					} else if (DEPT_VP_MAP_CONST.get(posIdToDeptMap.get(salMap.get(salShare.ParentId).position__c)) != salShare.UserOrGroupId){
						// the position's department has changed so delete the old dept VP sharing record
						deleteShares.add(salShare);
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
	
	public static void closeSharing(List<Position__c> closedPositions){
		// this method receives a list of closed positions and sets any corresponding
		//	salary__share records for VPs and Hiring Mgrs to be ReadOnly
		if (closedPositions.size() > 0){
			// create a list of corresponding salary records
			Set<ID> closedPositionSet = new Map<ID,Position__c>(closedPositions).keySet();
			Set<ID> closedSalarySet = new Map<ID,Salary__c>([select id from salary__c where position__c IN :closedPositionSet]).keySet();
			// go through the list of related sharing records in batch and update any Hiring Manager
			//	sharing records to be Read Only
			for(List<Salary__Share> batchOfShares:[select UserOrGroupId, RowCause, ParentId, Id, AccessLevel From Salary__Share where ParentId IN :closedSalarySet and (RowCause='Hiring_Manager__c' or RowCause='Department_VP__c')]){
				System.debug('batchOfShares=' + batchOfShares);
				for(Salary__Share salShare:batchOfShares){
					salShare.AccessLevel = 'Read';	
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
	
	public static void addSharing(Salary__c[] salaries, String apexType, String accessLevel){
		System.debug('creating bulk Salary__Share records');
		Salary__Share[] salShares = new Salary__Share[0];
		 
		for (Salary__c s:salaries){
			// Build Sharing Records for each salary
			Salary__Share ss = new Salary__Share();
			
			ss.ParentId = s.Id;
			if (apexType == 'Hiring_Manager__c'){
				ss.UserOrGroupId = s.position__r.Hiring_Manager__c;
				ss.RowCause = Schema.Salary__Share.RowCause.Hiring_Manager__c;
			} else if(apexType =='Department_VP__c'){
				ss.UserOrGroupId = DEPT_VP_MAP_CONST.get(s.position__r.department__c);
				ss.RowCause = Schema.Salary__Share.RowCause.Department_VP__c;
			}
			ss.AccessLevel = accessLevel;			
			System.debug('this is ss: ' + ss);
			salShares.add(ss);			
		}
		
		// Insert the sharing records
		if (salShares.size() > 0){
			try {
				System.debug('performing bulk Salary__Share insert');
				Database.insert(salShares,false);
			} catch (System.DmlException e) {
				System.debug('error bulk inserting position shares');
				for (Integer k = 0; k < e.getNumDml(); k++) {
					// Process exception here
					System.debug(e.getDmlMessage(k));
				}
			}
		}
	}
	
	// overloaded function
	public static void addSharing(Position__c[] positions,String accessLevel){
		// receives a list of positions; need to grab the corresponding salary records
		Map<ID,Position__c> posMap = new Map<ID,Position__c>(positions);
		List<Salary__c> allSalaries = [select id,position__c,position__r.hiring_manager__c,position__r.department__c from salary__c where position__c IN :posMap.keySet()];
		List<Salary__c> mgrSalaries = new List<Salary__c>();
		List<Salary__c> vpSalaries = new List<Salary__c>();
		
		for(Salary__c salary:allSalaries){
			if(salary.position__r.hiring_manager__c != null) mgrSalaries.add(salary);
			if(salary.position__r.department__c != null) vpSalaries.add(salary);	
		}
		// now call the share creation methods
		if (mgrSalaries.size() > 0) SalarySharing.addSharing(mgrSalaries,'Hiring_Manager__c',accessLevel);
		if (vpSalaries.size() > 0) SalarySharing.addSharing(vpSalaries,'Department_VP__c',accessLevel);
	}
}