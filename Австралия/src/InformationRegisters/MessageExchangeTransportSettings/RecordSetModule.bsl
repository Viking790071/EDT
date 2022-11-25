#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	For Each SetRow In ThisObject Do
		// Deleting insignificant characters (spaces) on the left and right for string parameters.
		TrimAllFieldValue(SetRow, "WebServiceAddress");
		TrimAllFieldValue(SetRow, "UserName");
	EndDo;
	
EndProcedure

Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Updating the platform cache for reading actual exchange message transport settings with 
	// the DataExchangeCached.DataExchangeSettings procedure.
	RefreshReusableValues();
	
EndProcedure

#EndRegion

#Region Private

Procedure TrimAllFieldValue(Record, Val Field)
	
	Record[Field] = TrimAll(Record[Field]);
	
EndProcedure

#EndRegion

#EndIf