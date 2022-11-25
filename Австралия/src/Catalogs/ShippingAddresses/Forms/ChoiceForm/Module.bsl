
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SetAsDefault(Command)
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Or CurrentData.IsDefault Then
		Return;
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Counterparty", CurrentData.Owner);
	ParametersStructure.Insert("NewDefaultShippingAddresses", CurrentData.Ref);
	
	SetAddressAsDefault(ParametersStructure);
	
	Items.List.Refresh();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetAddressAsDefault(ParametersStructure)
	
	ShippingAddressesServer.SetShippingAddressAsDefault(ParametersStructure);
	
EndProcedure

#EndRegion