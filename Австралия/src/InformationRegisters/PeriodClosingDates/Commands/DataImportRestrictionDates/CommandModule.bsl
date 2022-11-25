#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("DataImportRestrictionDates", True);
	OpenForm("InformationRegister.PeriodClosingDates.Form.PeriodClosingDates", FormParameters);
	
EndProcedure

#EndRegion
