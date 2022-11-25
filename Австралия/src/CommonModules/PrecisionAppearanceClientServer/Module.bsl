
#Region Public

// Returns company precision.
//
Function CompanyPrecision(Company) Export
	
	Return PrecisionAppearancetServerCall.CompanyPrecision(Company);
	
EndFunction

// Returns maximum precision in companies.
//
Function MaxCompanyPrecision() Export
	
	Return PrecisionAppearancetServerCall.MaxCompanyPrecision();
	
EndFunction

#EndRegion

