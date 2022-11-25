#Region Public

// Returns a flag that shows whether external users are enabled  in the application (the 
// UseExternalUsers functional option value).
//
// Returns:
//  Boolean - if True, external users are allowed.
//
Function UseExternalUsers() Export
	
	Return ExternalUsers.UseExternalUsers();
	
EndFunction

#EndRegion
