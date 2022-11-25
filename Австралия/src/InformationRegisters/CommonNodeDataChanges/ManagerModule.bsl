#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

Function SelectChanges(Val Node, Val MessageNumber) Export
	
	If TransactionActive() Then
		Raise NStr("ru = 'Выборка изменений данных запрещена в активной транзакции.'; en = 'Selection of data changes in an active transaction is not allowed.'; pl = 'Wybór zmiany danych jest zabroniony dla aktywnej transakcji.';es_ES = 'Selección de cambio de datos está prohibida en una transacción activa.';es_CO = 'Selección de cambio de datos está prohibida en una transacción activa.';tr = 'Etkin bir işlemde veri değişikliği seçimi yasaktır.';it = 'Selezione delle modifiche ai dati in una transazione attiva non disponibile.';de = 'Die Auswahl der Datenänderung ist in einer aktiven Transaktion verboten.'");
	EndIf;
	
	Result = New Array;
	
	BeginTransaction();
	Try
		
		Lock = New DataLock;
		LockItem = Lock.Add("InformationRegister.CommonNodeDataChanges");
		LockItem.SetValue("InfobaseNode", Node);
		Lock.Lock();
		
		QueryText =
		"SELECT
		|	CommonNodeDataChanges.InfobaseNode AS Node,
		|	CommonNodeDataChanges.MessageNo AS MessageNo
		|FROM
		|	InformationRegister.CommonNodeDataChanges AS CommonNodeDataChanges
		|WHERE
		|	CommonNodeDataChanges.InfobaseNode = &Node";
		
		Query = New Query;
		Query.SetParameter("Node", Node);
		Query.Text = QueryText;
		
		Selection = Query.Execute().Select();
		
		If Selection.Next() Then
			
			Result.Add(Selection.Node);
			
			If Selection.MessageNo = 0 Then
				
				RecordStructure = New Structure;
				RecordStructure.Insert("InfobaseNode", Node);
				RecordStructure.Insert("MessageNo", MessageNumber);
				AddRecord(RecordStructure);
				
			EndIf;
			
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return Result;
EndFunction

Procedure RecordChanges(Val Node) Export
	
	BeginTransaction();
	Try
		
		Lock = New DataLock;
		LockItem = Lock.Add("InformationRegister.CommonNodeDataChanges");
		LockItem.SetValue("InfobaseNode", Node);
		Lock.Lock();
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", Node);
		RecordStructure.Insert("MessageNo", 0);
		AddRecord(RecordStructure);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure DeleteChangeRecords(Val Node, Val MessageNumber = Undefined) Export
	
	BeginTransaction();
	Try
		
		Lock = New DataLock;
		LockItem = Lock.Add("InformationRegister.CommonNodeDataChanges");
		LockItem.SetValue("InfobaseNode", Node);
		Lock.Lock();
		
		If MessageNumber = Undefined Then
			
			QueryText =
			"SELECT
			|	1 AS Field1
			|FROM
			|	InformationRegister.CommonNodeDataChanges AS CommonNodeDataChanges
			|WHERE
			|	CommonNodeDataChanges.InfobaseNode = &Node";
			
		Else
			
			QueryText =
			"SELECT
			|	1 AS Field1
			|FROM
			|	InformationRegister.CommonNodeDataChanges AS CommonNodeDataChanges
			|WHERE
			|	CommonNodeDataChanges.InfobaseNode = &Node
			|	AND CommonNodeDataChanges.MessageNo <= &MessageNo
			|	AND CommonNodeDataChanges.MessageNo <> 0";
			
		EndIf;
		
		Query = New Query;
		Query.SetParameter("Node", Node);
		Query.SetParameter("MessageNo", MessageNumber);
		Query.Text = QueryText;
		
		If Not Query.Execute().IsEmpty() Then
			
			RecordStructure = New Structure;
			RecordStructure.Insert("InfobaseNode", Node);
			DeleteRecord(RecordStructure);
			
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Adds a record to the register by the passed structure values.
Procedure AddRecord(RecordStructure)
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "CommonNodeDataChanges");
	
EndProcedure

// Deletes a register record based on the passed structure values.
Procedure DeleteRecord(RecordStructure)
	
	DataExchangeServer.DeleteRecordSetFromInformationRegister(RecordStructure, "CommonNodeDataChanges");
	
EndProcedure

#EndRegion

#EndIf