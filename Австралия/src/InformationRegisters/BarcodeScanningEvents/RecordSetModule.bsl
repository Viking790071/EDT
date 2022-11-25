#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;	
	EndIf;
	
	For Each Record In ThisObject Do
		
		Query = New Query;
		Query.Text = 
			"SELECT
			|	BarcodeScanningEvents.Action AS Action
			|FROM
			|	InformationRegister.BarcodeScanningEvents AS BarcodeScanningEvents
			|WHERE
			|	BarcodeScanningEvents.UserGroup = &UserGroup
			|	AND BarcodeScanningEvents.DocumentType = &DocumentType";
		
		Query.SetParameter("DocumentType", Record.DocumentType);
		Query.SetParameter("UserGroup", Record.UserGroup);
		
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		If SelectionDetailRecords.Next() Then
			MessageToUser = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Rule for document ''%1'' for %2 already exists'; ru = 'Правило для документов %1 для %2 уже существует';pl = 'Reguła dokumentu ''%1'' dla %2 już istnieje';es_ES = 'La regla para el documento ''%1'' para %2 ya existe';es_CO = 'La regla para el documento ''%1'' para %2 ya existe';tr = '%2 için ''%1'' belgesine ilişkin kural zaten var.';it = 'La regola per il documento ""%1"" per %2 già esiste';de = 'Regel für Dokument ''%1'' für %2 existiert bereits'"),
				Common.ObjectAttributeValue(Record.DocumentType, "Synonym"),
				Record.UserGroup);
			CommonClientServer.MessageToUser(
				MessageToUser,
				SelectionDetailRecords.Action,
				,
				,
				Cancel);
			EndIf;
			
	EndDo;
	
EndProcedure

#EndRegion

#EndIf