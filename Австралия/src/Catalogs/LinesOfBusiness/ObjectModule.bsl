#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	ProfitGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("IncomeSummary");
	
EndProcedure

#EndRegion

#EndIf