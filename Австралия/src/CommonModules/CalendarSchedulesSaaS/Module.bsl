#Region Public

#Region ForCallsFromOtherSubsystems

// OnlineUserSupport.SaaS.ClassifiersOperations

// See ClassifiersOperationsSaaSOverridable.OnProcessDataArea. 
Procedure OnProcessDataArea(ID, Version, AdditionalParameters) Export
	
	If ID <> CalendarSchedules.ClassifierID() Then
		Return;
	EndIf;

	If Not AdditionalParameters.Property(ID) Then
		Return;
	EndIf;
	
	UpdateParameters = AdditionalParameters[ID];
	
	CalendarSchedules.FillDataDependentOnBusinessCalendars(UpdateParameters.ChangesTable);
	
EndProcedure

// End OnlineUserSupport.SaaS.ClassifiersOperations

#EndRegion

#EndRegion
