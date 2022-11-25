#Region Public

Function EDIExecuteCommandTimeConsumingOperation(DocumentsArray, Handler) Export
	
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("DocumentsArray", DocumentsArray);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.WaitForCompletion = 0;
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'EDI exchange'; ru = 'Электронный документооборот';pl = 'Elektroniczna wymiana dokumentów';es_ES = 'Intercambio EDI';es_CO = 'Intercambio EDI';tr = 'EDI değişimi';it = 'Scambio di documenti elettronici';de = 'EDI-Austausch'");
	
	TimeConsumingOperation =
		TimeConsumingOperations.ExecuteInBackground(Handler, ProcedureParameters, ExecutionParameters);
	
	Return TimeConsumingOperation;
	
EndFunction

Procedure CheckConnection(EDIProfile, HasErrors) Export
	
	EDIServer.CheckConnection(EDIProfile, HasErrors);
	
EndProcedure

Function EDICommandDescription(CommandName, CommandsAddressInTempStorage) Export
	
	EDICommands = GetFromTempStorage(CommandsAddressInTempStorage);
	
	For Each EDICommand In EDICommands.FindRows(New Structure("CommandNameAtForm", CommandName)) Do
		Return Common.ValueTableRowToStructure(EDICommand);
	EndDo;
	
EndFunction

Function GetEDIState(Document) Export
	
	Return EDIServer.GetEDIState(Document);
	
EndFunction

Function DocumentWasSent(DocumentRef) Export
	
	Return EDIServer.DocumentWasSent(DocumentRef);
	
EndFunction

Function ProhibitEDocumentsChanging() Export
	
	Return EDIServer.ProhibitEDocumentsChanging();
	
EndFunction

Function CounterpartyInfoToCheck(Counterparty) Export
	
	Return EDIServer.CounterpartyInfoToCheck(Counterparty);
	
EndFunction

#EndRegion