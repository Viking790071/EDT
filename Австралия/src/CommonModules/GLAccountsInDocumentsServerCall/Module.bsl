
#Region Public

Function GetCounterpartyGLAccounts(StructureData) Export

	Return GLAccountsInDocuments.GetCounterpartyGLAccounts(StructureData);

EndFunction

Function GetGLAccountsDescription(FillingData) Export

	GLAccounts = "";
	GLAccountsFilled = True;
	
	UnfilledAccountPresentation = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	DisabledAccountPresentation = GLAccountsInDocumentsClientServer.GetDisabledGLAccountPresentation();
	
	FirstAccount = True;
	For Each Account In FillingData Do
		If ValueIsFilled(Account.Value) Then
			GLAccountPresentation = Common.ObjectAttributeValue(Account.Value, "Code");
			GLAccounts = GLAccounts + ?(FirstAccount, "", ", ") + GLAccountPresentation;
		Else
			GLAccounts			= GLAccounts + UnfilledAccountPresentation;
			GLAccountsFilled	= False;
		EndIf;
		
		If FirstAccount Then
			FirstAccount = False;
			UnfilledAccountPresentation = ", " + UnfilledAccountPresentation;
		EndIf;
		
	EndDo;
	
	FillingData.Insert("GLAccounts",		?(IsBlankString(GLAccounts), DisabledAccountPresentation, GLAccounts));
	FillingData.Insert("GLAccountsFilled",	GLAccountsFilled);
	
	Return FillingData;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(DocumentRef, StructureData) Export
	
	DocumentName = DocumentRef.Metadata().Name;
	Return Documents[DocumentName].GetIncomeAndExpenseItemsGLAMap(StructureData);
	
EndFunction

Procedure CheckItemRegistration(StructureData, TabName = "Header") Export
	
	GLAccountsInDocuments.CheckItemRegistration(StructureData, TabName);
	
EndProcedure

Function IsIncomeAndExpenseGLA(GLAccount) Export
	
	Return GLAccountsInDocuments.IsIncomeAndExpenseGLA(GLAccount);
	
EndFunction

#EndRegion

