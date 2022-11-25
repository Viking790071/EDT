#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	UseFilter = ValueIsFilled(Parameters.Counterparty);
	If UseFilter Then
		Counterparties = New Array;
		Counterparties.Add(Parameters.Counterparty);
		Counterparties.Add(Catalogs.Counterparties.EmptyRef());
		DriveClientServer.SetListFilterItem(List, "Counterparty", Counterparties, UseFilter);
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion
