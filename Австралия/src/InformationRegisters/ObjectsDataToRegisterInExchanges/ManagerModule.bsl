#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

Procedure AddObjectToAllowedObjectsFilter(Val Object, Val Recipient) Export
	
	If Not ObjectIsInRegister(Object, Recipient) Then
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", Recipient);
		RecordStructure.Insert("Ref", Object);
		
		AddRecord(RecordStructure, True);
	EndIf;
	
EndProcedure

Function ObjectIsInRegister(Object, InfobaseNode) Export
	
	QueryText = "
	|SELECT 1
	|FROM
	|	InformationRegister.ObjectsDataToRegisterInExchanges AS ObjectsDataToRegisterInExchanges
	|WHERE
	|	  ObjectsDataToRegisterInExchanges.InfobaseNode           = &InfobaseNode
	|	AND ObjectsDataToRegisterInExchanges.Ref = &Object
	|";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.SetParameter("Object", Object);
	Query.Text = QueryText;
	
	Return Not Query.Execute().IsEmpty();
EndFunction

#EndRegion

#Region Private

// Adds a record to the register by the passed structure values.
Procedure AddRecord(RecordStructure, Import = False)
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "ObjectsDataToRegisterInExchanges", Import);
	
EndProcedure

#EndRegion

#EndIf