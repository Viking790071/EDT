#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	FillByDefault();

EndProcedure

#EndRegion

#Region Private

Procedure FillByDefault()
	
	If Not ValueIsFilled(Company) Then
		Company = DriveReUse.GetUserDefaultCompany();
	EndIf;
	
EndProcedure

#EndRegion

#EndIf