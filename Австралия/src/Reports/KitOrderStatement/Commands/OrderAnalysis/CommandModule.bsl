#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Filter = New Structure;
	Filter.Insert("KitOrder", GetOrderArray(CommandParameter));
	
	OpenForm("Report.KitOrderStatement.Form",
		New Structure("UsePurposeKey, Filter, GenerateOnOpen", CommandParameter, Filter, True),
		,
		"KitOrder=" + CommandParameter,
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function GetOrderArray(CommandParameter)

	OrdersArray = New Array;
	
	If TypeOf(CommandParameter) = Type("Array") Then
		For Each Document In CommandParameter Do
			If TypeOf(Document) = Type("DocumentRef.Production") Then
				ProductionOrder = Common.ObjectAttributeValue(Document, "BasisDocument");
				OrdersArray.Add(ProductionOrder);
			Else
				OrdersArray.Add(Document);
			EndIf;
		EndDo;
	EndIf;
	
	Return OrdersArray;

EndFunction

#EndRegion