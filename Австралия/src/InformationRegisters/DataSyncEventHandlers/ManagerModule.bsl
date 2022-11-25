#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// The procedure registers the need to execute infobase update handlers after getting data from each 
// subordinate DIB node.
//
Procedure RegisterInfobaseDataUpdate() Export
	
	SetPrivilegedMode(True);
	
	DIBExchangePlans = StandardSubsystemsCached.DIBExchangePlans();
	Query = New Query();
	Query.SetParameter("MasterNode", ExchangePlans.MasterNode());
	For Each ExchangePlanName In DIBExchangePlans Do
		If StrFind(DataExchangeServer.ExchangePlanPurpose(ExchangePlanName), "DIB") = 0 Then
			Continue;
		EndIf;
		
		Query.Text =
		"SELECT
		|	ExchangePlan.Ref AS Ref
		|FROM
		|	ExchangePlan.[ExchangePlanName] AS ExchangePlan
		|WHERE
		|	NOT ExchangePlan.ThisNode
		|	AND NOT ExchangePlan.DeletionMark
		|	AND ExchangePlan.Ref <> &MasterNode";
		Query.Text = StrReplace(Query.Text, "[ExchangePlanName]", ExchangePlanName);
		NodeSelection = Query.Execute().Select();
		While NodeSelection.Next() Do
			
			RecordStructure = New Structure;
			RecordStructure.Insert("InfobaseNode", NodeSelection.Ref);
			RecordStructure.Insert("Event", "AfterGetData");
			RecordStructure.Insert("Handler", "InfobaseUpdate");
			DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "DataSyncEventHandlers");
			
		EndDo;
	EndDo;
	
	
EndProcedure

// The procedure executes handlers registered for exchange plan node events.
//
// Parameters:
//  InfobaseNode - ExchangePlanRef - an infobase node for handler execution.
//  Event - String - a name of event whose handlers are to be executed.
//
Procedure ExecuteHandlers(InfobaseNode, Event) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = "SELECT
	|	Handlers.Handler
	|FROM
	|	InformationRegister.DataSyncEventHandlers AS Handlers
	|WHERE
	|	Handlers.InfobaseNode = &InfobaseNode
	|	AND Handlers.Event = &Event";
	
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.SetParameter("Event", Event);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		If Selection.Handler = "InfobaseUpdate" Then
			
			InfobaseUpdateInternal.OnGetFirstDIBExchangeMessageAfterUpdate();
			
			RecordStructure = New Structure;
			RecordStructure.Insert("InfobaseNode", InfobaseNode);
			RecordStructure.Insert("Event", "AfterGetData");
			RecordStructure.Insert("Handler", "InfobaseUpdate");
			DataExchangeServer.DeleteRecordSetFromInformationRegister(RecordStructure, "DataSyncEventHandlers");
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf