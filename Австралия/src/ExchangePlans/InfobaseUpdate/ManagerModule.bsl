#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Returns references to nodes that have a smaller position in queue than the passed one.
//
// Parameters:
//  PositionInQueue	 - Number - the queue position of the data processor.
// 
// Returns:
// 	Array - an array of the following values:
//		* ExchangePlanRef.InfobaseUpdate
//
Function EarlierQueueNodes(PositionInQueue) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	InfobaseUpdate.Ref AS Ref
	|FROM
	|	ExchangePlan.InfobaseUpdate AS InfobaseUpdate
	|WHERE
	|	InfobaseUpdate.PositionInQueue < &PositionInQueue
	|	AND NOT InfobaseUpdate.ThisNode
	|	AND InfobaseUpdate.PositionInQueue <> 0";
	
	Query.SetParameter("PositionInQueue", PositionInQueue);
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

// Searches for the exchange plan node by its queue and returns a reference to it.
// If there is no node, it will be created.
//
// Parameters:
//  PositionInQueue	 - Number - the queue position of the data processor.
// 
// Returns:
//  ExchangePlanRef.InfobaseUpdate.
//
Function NodeInQueue(PositionInQueue) Export
	
	If TypeOf(PositionInQueue) <> Type("Number") Or PositionInQueue = 0 Then
		Raise NStr("ru = 'Невозможно получить узел плана обмена InfobaseUpdate, т.к. не передан номер очереди.'; en = 'Cannot get the node of InfobaseUpdate exchange plan because the position in queue is not provided.'; pl = 'Nie można uzyskać węzła planu wymiany InfobaseUpdate exchange plan, ponieważ pozycja w kolejce nie została przekazana.';es_ES = 'Es imposible recibir el nodo del plan de cambio InfobaseUpdate, porque no ha sido transmitido el número de cola.';es_CO = 'Es imposible recibir el nodo del plan de cambio InfobaseUpdate, porque no ha sido transmitido el número de cola.';tr = 'Sıra numarası verilmediği için VeriTabanıGüncelleme alışveriş planın ünitesi elde edilemez.';it = 'Non è possibile ricevere il nodo del piano di scambio InfobaseUpdate, perché non è stato trasmesso il numero di turno.';de = 'Es ist nicht möglich, den Knoten InfobaseUpdate des Austauschplans zu erhalten, da die Warteschlangennummer nicht übertragen wurde.'");
	EndIf;
	
	Query = New Query(
		"SELECT
		|	InfobaseUpdate.Ref AS Ref
		|FROM
		|	ExchangePlan.InfobaseUpdate AS InfobaseUpdate
		|WHERE
		|	InfobaseUpdate.PositionInQueue = &PositionInQueue
		|	AND NOT InfobaseUpdate.ThisNode");
	Query.SetParameter("PositionInQueue", PositionInQueue);
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Node = Selection.Ref;
	Else
		BeginTransaction();
		
		Try
			Locks = New DataLock;
			Lock = Locks.Add("ExchangePlan.InfobaseUpdate");
			Lock.SetValue("PositionInQueue", PositionInQueue);
			Locks.Lock();
			
			Selection = Query.Execute().Select();
			
			If Selection.Next() Then
				Node = Selection.Ref;
			Else
				QueueString = String(PositionInQueue);
				ObjectNode = CreateNode();
				ObjectNode.PositionInQueue = PositionInQueue;
				ObjectNode.SetNewCode(QueueString);
				ObjectNode.Description = QueueString;
				ObjectNode.Write();
				Node = ObjectNode.Ref;
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndIf;
	
	Return Node;
	
EndFunction

#EndRegion

#EndIf