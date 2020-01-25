public class OpenPositionListApply_Controller {

	// declare local vars
	private String selectedPositionId;
	
	// constructor
	public OpenPositionListApply_Controller() {
		// initialize class vars
		this.selectedPositionId = System.currentPageReference().getParameters().get('posid');
	}
	
	public void ApplyForOpenPosition() {
		if (this.selectedPositionId != null) {
			// retrieve the current user's email
			String email = [Select id, email from User where Id = :UserInfo.getUserId()].email;
			
			// create a candidate
			Candidate__c candidate = new Candidate__c(First_Name__c=UserInfo.getFirstName(),
				Last_Name__c=UserInfo.getLastName(),Email__c=email);
			
			// create job application
			CandidateKeyWebService.submitEmployeeReferral(this.selectedPositionId, candidate);
		}		
	}

    public PageReference returnToList() {
    	return Page.OpenPositionList;
    }
}