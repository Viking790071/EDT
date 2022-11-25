
#Region Public

// Returns company precision.
//
Function CompanyPrecision(Company) Export
	
	Return PrecisionAppearancetServer.CompanyPrecision(Company);
	
EndFunction

// Returns maximum precision in companies.
//
Function MaxCompanyPrecision() Export
	
	Return PrecisionAppearancetServer.MaxCompanyPrecision();
	
EndFunction

#EndRegion

