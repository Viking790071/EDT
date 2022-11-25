#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	MessagesChannel = Description;
	
	BodyContent = MessageBody.Get();
	
	// StandardSubsystems.SaaS.CoreSaaS
	MessagesSaaS.MessagesBeforeSend(MessagesChannel, BodyContent);
	// End StandardSubsystems.SaaS.CoreSaaS
	
	MessageBody = New ValueStorage(BodyContent);
	
EndProcedure

#EndRegion

#EndIf