
#Region Internal

Function StartAccountingEntriesChangingInBackgroundJob(ProcedureParameters) Export
	
	If ProcedureParameters.Property("Document") Then
		
		BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Change the accounting entries status for document ""%1""'; ru = 'Изменить статус бухгалтерских проводок для документа ""%1""';pl = 'Zmień status wpisów księgowych dla dokumentu ""%1""';es_ES = 'Cambiar el estado de las entradas contables para el documento ""%1""';es_CO = 'Cambiar el estado de las entradas contables para el documento ""%1""';tr = '""%1"" belgesi için muhasebe girişleri durumunu değiştir';it = 'Modificare lo stato degli inserimenti contabili per il documento ""%1""';de = 'Buchungsstatus für Dokument ""%1 "" ändern'"),
			ProcedureParameters.Document);
	Else
		
		BackgroundJobDescription = NStr("en = 'Change accounting entries statuses for multiple documents'; ru = 'Изменить статусы бухгалтерских проводок для нескольких документов';pl = 'Zmień statusy wpisów księgowych dla wielu dokumentów';es_ES = 'Cambiar el estado de las entradas contables para múltiples documentos';es_CO = 'Cambiar el estado de las entradas contables para múltiples documentos';tr = 'Birden fazla belgenin muhasebe girişleri durumunu değiştir';it = 'Modificare gli stati degli inserimenti contabili per documenti multipli';de = 'Status der Buchhaltungseinträge für mehrere Dokumente ändern'");
		
	EndIf;
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(ProcedureParameters.UUID);
	ExecutionParameters.BackgroundJobDescription = BackgroundJobDescription;
	
	BackgroundJobResult = TimeConsumingOperations.ExecuteInBackground(
		"AccountingApprovalServer.ChangeDocumentAccountingEntriesStatus",
		ProcedureParameters,
		ExecutionParameters);
	
	Return BackgroundJobResult;
	
EndFunction

Function GetParametersApproval(Document) Export

	PreventRepostingDocuments = GetFunctionalOption("PreventRepostingDocumentsWithApprovedAccountingEntries");
	HasRightChangeApprovedDocuments = Users.IsFullUser(Users.AuthorizedUser())
		Or AccessManagement.HasRole("ChangeApprovedDocuments");
			
	ParametersStructure = AccountingApprovalServer.GetAccountinEntriesStatus(Document);
	If ParametersStructure = Undefined Then
		ParametersStructure	= New Structure;
	EndIf;
	
	ParametersStructure.Insert("UseAccountingApproval", DriveServerCall.GetFunctionalOptionValue("UseAccountingApproval"));
	ParametersStructure.Insert("PreventRepostingDocuments", PreventRepostingDocuments);
	ParametersStructure.Insert("HasRightChangeApprovedDocuments", HasRightChangeApprovedDocuments);
	
	Return ParametersStructure;

EndFunction

Function GetMasterByChartOfAccounts(ChartOfAccounts) Export
	
	Return AccountingApprovalServer.GetMasterByChartOfAccounts(ChartOfAccounts);

EndFunction

#EndRegion