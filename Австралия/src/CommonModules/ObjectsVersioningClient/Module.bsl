#Region Public

// Opens object version report in version comparison mode.
//
// Parameters:
//  Reference                       - AnyRef - reference to the versioned object;
//  SerializedObjectAddress - String - address of binary data of the compared object version in the 
//                                          temporary storage.
//
Procedure OpenReportOnChanges(Ref, SerializedObjectAddress) Export
	
	Parameters = New Structure;
	Parameters.Insert("Ref", Ref);
	Parameters.Insert("SerializedObjectAddress", SerializedObjectAddress);
	
	OpenForm("InformationRegister.ObjectsVersions.Form.ObjectVersionsReport", Parameters);
	
EndProcedure

// Opens the report for the object version passed in SerializedObjectAddress parameter.
//
// Parameters:
//  Reference                       - AnyRef - reference to the versioned object;
//  SerializedObjectAddress - String - address of the object version binary data in the temporary storage.
//
Procedure OpenReportOnObjectVersion(Ref, SerializedObjectAddress) Export
	
	Parameters = New Structure;
	Parameters.Insert("Ref", Ref);
	Parameters.Insert("SerializedObjectAddress", SerializedObjectAddress);
	Parameters.Insert("ByVersion", True);
	
	OpenForm("InformationRegister.ObjectsVersions.Form.ObjectVersionsReport", Parameters);
	
EndProcedure

#EndRegion

#Region Internal

// Opens a report on a version or version comparison.
//
// Parameters:
//	Reference - Reference to the object
//	ComparedVerions - Array - Contains array of compared versions or if there is only one version 
//	opens the version report.
//
Procedure OpenVersionComparisonReport(Ref, VersionsToCompare) Export
	
	ReportParameters = New Structure;
	ReportParameters.Insert("Ref", Ref);
	ReportParameters.Insert("VersionsToCompare", VersionsToCompare);
	OpenForm("InformationRegister.ObjectsVersions.Form.ObjectVersionsReport", ReportParameters);
	
EndProcedure

#EndRegion
