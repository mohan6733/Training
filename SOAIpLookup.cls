public class SOAIpLookup {

	public Job_Posting_Site__c jobSite {get;set;}
	public ApexPages.standardController controller {get;set;}
	public String ipaddress {get;set;}
	private StrikeIronInfo__c info {
		get{
			if (info == null) {
				info = [select userid__c,password__c from strikeironinfo__c where Active__c = true limit 1];
			}
			return info;	
		}
		set;
	}
	
	public SOAIpLookup(ApexPages.StandardController stdController) {
    	// constructor
    	controller = stdController;
        this.jobSite = (Job_Posting_Site__c)stdController.getRecord();      
    }
	
	public PageReference strikeIronIpCheck(){
		System.debug('############### ENTERING strikeIronIpCheck() ###############');
		
		// Create the stub
		System.debug('Creating the DNSSoap stub...');
		strikeironIplookup.DNSSoap dns = new strikeironIplookup.DNSSoap();

		// Set up the license header
		System.debug('Setting up the header...');
		dns.LicenseInfo = new strikeiron.LicenseInfo();
		dns.LicenseInfo.RegisteredUser = new strikeiron.RegisteredUser();
		System.debug('User ID: ' + info.userid__c);
		dns.LicenseInfo.RegisteredUser.UserID = info.userid__c;
		System.debug('Password: ' + info.password__c);
		dns.LicenseInfo.RegisteredUser.Password = info.password__c;
		// Make the Web service call
		System.debug('Calling Strikeiron service to check ip for: ' + jobSite.URL__c );
		strikeironIplookup.DNSInfo info = dns.DNSLookup(jobSite.URL__c);
		System.debug(info);
		ipaddress = info.AddressList.string_x[0];
		System.debug('Retrieved IP address: ' + ipaddress);
		
		System.debug('############### LEAVING strikeIronIpCheck() ###############');
		return null;
	}
}