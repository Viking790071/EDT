#Region Private

Function InfobaseSecurityProfile() Export
	
	// An explicit call to the optional subsystem is required, as Common.CommonModule can be denied 
	// by security profile.
	// Return SafeModeManager.InfobaseSecurityProfile(True);
	Return Undefined;
	
EndFunction	

#EndRegion