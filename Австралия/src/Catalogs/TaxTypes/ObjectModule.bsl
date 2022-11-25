#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	GLAccount					= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("TaxPayable");
	GLAccountForReimbursement	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("TaxRefund");	
	
EndProcedure

#EndRegion

#EndIf