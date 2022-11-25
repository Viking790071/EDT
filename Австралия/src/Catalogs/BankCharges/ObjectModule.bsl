#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	GLAccount			= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("BankAccount");
	GLExpenseAccount	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("BankFeesExpenseAccount");

EndProcedure

#EndRegion

#EndIf