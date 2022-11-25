#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Not Parameters.Property("ExchangeNodeRef", ExchangeNodeRef) Then
		Cancel = True;
		Return;
	EndIf;
	
	Title = ExchangeNodeRef;
	
	ReadMessageNumbers();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

// The procedure writes modified data and closes the form.
//
&AtClient
Procedure WriteNodeChanges(Command)
	
	WriteMessageNumbers();
	Notify("ExchangeNodeDataEdit", ExchangeNodeRef, ThisObject);
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function ThisObject() 
	
	Return FormAttributeToValue("Object");
	
EndFunction

&AtServer
Procedure ReadMessageNumbers()
	
	Data = ThisObject().GetExchangeNodeParameters(ExchangeNodeRef, "SentNo, ReceivedNo");
	FillPropertyValues(ThisObject, Data);
	
EndProcedure

&AtServer
Procedure WriteMessageNumbers()
	
	Data = New Structure("SentNo, ReceivedNo", SentNo, ReceivedNo);
	ThisObject().SetExchangeNodeParameters(ExchangeNodeRef, Data);
	
EndProcedure

#EndRegion
