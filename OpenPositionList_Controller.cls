public class OpenPositionList_Controller {
	
	public String jobIdAppliedFor {get;set;}
	private List<Position__c> positions {get;set;}
	
	public OpenPositionList_Controller() {
		System.debug('Constructing OpenPositionList_Controller');
		System.debug('Querying for open positions...');
    	this.positions = [Select id, name, type__c, start_date__c, skills_required__c, responsibilities__c, location__c, job_description__c, department__c, date_opened__c 
			from Position__c where status__c = 'Open' and sub_status__c = 'Approved' 
			order by department__c, name LIMIT 200];
			
		for(Position__c pos : positions) {
			System.debug(pos);
		}
			
		System.debug('Query for open and approved positions returned ' + positions.size() + ' records.');
		System.debug('Construction Complete');
	}
		
	public List<Position__c> getOpenPositions() {
		System.debug('Retrieving Open Positions');
		return this.positions;
    }
}